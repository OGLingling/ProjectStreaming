// services/scrape_queue.js
// Cola en memoria — sin Redis, sin costo extra.
// Usa los modelos Content y Episode que ya existen en tu schema.

const { PrismaClient } = require('@prisma/client');
const VideoScraper = require('./scraper_service');

const prisma = new PrismaClient();

// En Render gratis: 1. En Railway 1GB+: 2.
const MAX_CONCURRENT = Number(process.env.SCRAPER_CONCURRENT) || 1;

// TTL de la URL scrapeada (10 horas por defecto, configurable por env)
const URL_TTL_MS = Number(process.env.STREAM_TTL_MS) || 10 * 60 * 60 * 1000;

// Si quedan menos de estas horas, se considera "próximo a vencer"
const REFRESH_THRESHOLD_MS = Number(process.env.STREAM_REFRESH_THRESHOLD_MS) || 2 * 60 * 60 * 1000;

let running = 0;
const pending = [];

// ─── UTILS ───────────────────────────────────────────────────────────────────
function extractDomain(url) {
  try { return new URL(url).hostname; } catch (_) { return 'unknown'; }
}

function detectStreamType(url) {
  const lower = String(url || '').toLowerCase();
  if (lower.includes('.m3u8')) return 'hls';
  if (lower.includes('.mp4')) return 'mp4';
  return 'unknown';
}

// ─── ENQUEUE ─────────────────────────────────────────────────────────────────
/**
 * Encola un scraping. Si `force` es true, saltea la verificación de BD y
 * re-scrapea aunque la URL aún sea válida.
 */
function enqueue(tmdbId, type, season = 1, episode = 1, force = false) {
  return new Promise((resolve, reject) => {
    pending.push({
      tmdbId: String(tmdbId),
      type: String(type),
      season: Number(season),
      episode: Number(episode),
      force,
      resolve,
      reject
    });
    tick();
  });
}

function tick() {
  if (running >= MAX_CONCURRENT || pending.length === 0) return;
  const job = pending.shift();
  running++;
  processJob(job)
    .then(job.resolve)
    .catch(job.reject)
    .finally(() => { running--; tick(); });
}

// ─── PROCESS ─────────────────────────────────────────────────────────────────
async function processJob(job) {
  const { tmdbId, type, season, episode, force } = job;
  const isTV = type === 'tv';
  const label = `[queue] ${type}/${tmdbId}${isTV ? ` S${season}E${episode}` : ''}`;
  const startAt = Date.now();

  console.log(`${label} → iniciando scrape${force ? ' (forzado)' : ''}`);

  // ── Si no es forzado, verificar si la BD ya tiene una URL vigente ──────────
  if (!force) {
    const existing = await getCachedStreamFromDB(tmdbId, type, season, episode);
    if (existing) {
      const remaining = Math.round((existing.streamExpiresAt - Date.now()) / 60000);
      console.log(`${label} → BD hit (${remaining} min restantes), saltando scrape`);
      return { url: existing.videoUrl, source: extractDomain(existing.videoUrl), fromCache: true };
    }
  }

  // Registra el job como "en proceso"
  await prisma.scrapeJob.upsert({
    where: { tmdbId_type_season_episode: { tmdbId, type, season, episode } },
    create: { tmdbId, type, season, episode, status: 'processing', attempts: 1 },
    update: { status: 'processing', attempts: { increment: 1 }, error: null, updatedAt: new Date() }
  }).catch(() => {});

  try {
    const result = await VideoScraper.extractStreamUrl({ tmdbId, type, season, episode });

    if (!result.success || !result.candidates?.length) {
      throw new Error('No se encontró ninguna URL válida (.m3u8 o .mp4)');
    }

    // ── Guarda TODAS las URLs encontradas, la primera es la principal ─────────
    const allCandidates = result.candidates; // array de strings
    const primaryUrl   = allCandidates[0];
    const source       = extractDomain(primaryUrl);
    const streamType   = detectStreamType(primaryUrl);
    const expiresAt    = new Date(Date.now() + URL_TTL_MS);
    const duration     = Date.now() - startAt;

    console.log(`${label} → ${allCandidates.length} candidato(s) encontrados [tipo: ${streamType}]`);

    if (isTV) {
      // ── Serie: guarda en Episode.videoUrl ─────────────────────────────────
      const episodeRecord = await prisma.episode.findFirst({
        where: {
          episodeNumber: episode,
          season: {
            seasonNumber: season,
            content: { tmdbId }
          }
        },
        select: { id: true }
      });

      if (episodeRecord) {
        await prisma.episode.update({
          where: { id: episodeRecord.id },
          data: {
            videoUrl: primaryUrl,
            streamSource: source,
            streamExpiresAt: expiresAt
          }
        });
        console.log(`${label} → Episodio actualizado (${streamType}): ${primaryUrl.substring(0, 70)}...`);
      } else {
        console.warn(`${label} → episodio no encontrado en BD (no sincronizado con TMDB)`);
      }

    } else {
      // ── Película: guarda en Content.videoUrl ───────────────────────────────
      await prisma.content.update({
        where: { tmdbId },
        data: {
          videoUrl: primaryUrl,
          streamSource: source,
          streamExpiresAt: expiresAt
        }
      });
      console.log(`${label} → Película actualizada (${streamType}): ${primaryUrl.substring(0, 70)}...`);
    }

    // Registro de auditoría en ScrapeLog
    await prisma.scrapeLog.create({
      data: {
        targetUrl: `${type}/${tmdbId}${isTV ? `/${season}/${episode}` : ''}`,
        success: true,
        streamUrl: allCandidates.join('\n'), // guarda todos los candidatos
        duration
      }
    }).catch(() => {});

    await prisma.scrapeJob.update({
      where: { tmdbId_type_season_episode: { tmdbId, type, season, episode } },
      data: { status: 'done', error: null, updatedAt: new Date() }
    }).catch(() => {});

    console.log(`${label} → OK en ${duration}ms (fuente: ${source})`);
    return { url: primaryUrl, source, allCandidates, streamType, duration };

  } catch (error) {
    const duration = Date.now() - startAt;
    console.error(`${label} → FALLÓ: ${error.message}`);

    await prisma.scrapeLog.create({
      data: {
        targetUrl: `${type}/${tmdbId}${isTV ? `/${season}/${episode}` : ''}`,
        success: false,
        error: error.message,
        duration
      }
    }).catch(() => {});

    await prisma.brokenLink.create({
      data: {
        url: `${type}/${tmdbId}`,
        error: error.message,
        provider: 'vidsrc'
      }
    }).catch(() => {});

    await prisma.scrapeJob.update({
      where: { tmdbId_type_season_episode: { tmdbId, type, season, episode } },
      data: { status: 'failed', error: error.message, updatedAt: new Date() }
    }).catch(() => {});

    throw error;
  }
}

// ─── BD CACHE CHECK ──────────────────────────────────────────────────────────
/**
 * Busca en la BD si ya existe una URL vigente y no próxima a vencer.
 * Retorna el registro si es válido, o null si hay que re-scrapear.
 */
async function getCachedStreamFromDB(tmdbId, type, season, episode) {
  const isTV = type === 'tv';
  const now = new Date();
  const thresholdDate = new Date(Date.now() + REFRESH_THRESHOLD_MS);

  try {
    if (isTV) {
      const ep = await prisma.episode.findFirst({
        where: {
          episodeNumber: episode,
          season: {
            seasonNumber: season,
            content: { tmdbId }
          },
          videoUrl: { not: null },
          streamExpiresAt: { gt: thresholdDate } // aún le queda más del umbral
        },
        select: { videoUrl: true, streamExpiresAt: true }
      });
      return ep?.videoUrl ? { videoUrl: ep.videoUrl, streamExpiresAt: ep.streamExpiresAt.getTime() } : null;
    } else {
      const content = await prisma.content.findFirst({
        where: {
          tmdbId,
          videoUrl: { not: null },
          streamExpiresAt: { gt: thresholdDate }
        },
        select: { videoUrl: true, streamExpiresAt: true }
      });
      return content?.videoUrl ? { videoUrl: content.videoUrl, streamExpiresAt: content.streamExpiresAt.getTime() } : null;
    }
  } catch (_) {
    return null;
  }
}

// ─── STATS ───────────────────────────────────────────────────────────────────
function getQueueStats() {
  return { running, pending: pending.length };
}

module.exports = { enqueue, getQueueStats, getCachedStreamFromDB };
