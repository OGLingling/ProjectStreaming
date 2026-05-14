// services/scrape_queue.js
// Cola en memoria — sin Redis, sin costo extra.
// Usa los modelos Content y Episode que ya existen en tu schema.

const { PrismaClient } = require('@prisma/client');
const VideoScraper = require('./scraper_service');

const prisma = new PrismaClient();

// En Render gratis: 1. En Railway 1GB+: 2.
const MAX_CONCURRENT = Number(process.env.SCRAPER_CONCURRENT) || 1;

// 10 horas — conservador para evitar URLs muertas antes de refrescar
const URL_TTL_MS = 10 * 60 * 60 * 1000;

let running = 0;
const pending = [];

// ─── ENQUEUE ─────────────────────────────────────────────────────────────────
function enqueue(tmdbId, type, season = 1, episode = 1) {
  return new Promise((resolve, reject) => {
    pending.push({
      tmdbId: String(tmdbId),
      type: String(type),
      season: Number(season),
      episode: Number(episode),
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
  const { tmdbId, type, season, episode } = job;
  const isTV = type === 'tv';
  const label = `[queue] ${type}/${tmdbId}${isTV ? ` S${season}E${episode}` : ''}`;
  const startAt = Date.now();

  console.log(`${label} → iniciando scrape`);

  // Registra el job como "en proceso"
  await prisma.scrapeJob.upsert({
    where: { tmdbId_type_season_episode: { tmdbId, type, season, episode } },
    create: { tmdbId, type, season, episode, status: 'processing', attempts: 1 },
    update: { status: 'processing', attempts: { increment: 1 }, error: null }
  }).catch(() => {});

  try {
    const result = await VideoScraper.extractStreamUrl({ tmdbId, type, season, episode });

    if (!result.success || !result.candidates?.[0]) {
      throw new Error('No se encontró ninguna URL válida');
    }

    const url = result.candidates[0];
    const source = extractDomain(url);
    const expiresAt = new Date(Date.now() + URL_TTL_MS);
    const duration = Date.now() - startAt;

    if (isTV) {
      // ── Serie: guarda en Episode.videoUrl ──────────────────────────────
      // Navega Content → Season → Episode usando las relaciones existentes
      const episodeRecord = await prisma.episode.findFirst({
        where: {
          episodeNumber: episode,
          season: {
            seasonNumber: season,
            content: { tmdbId }  // tmdbId es String en tu schema
          }
        },
        select: { id: true }
      });

      if (episodeRecord) {
        await prisma.episode.update({
          where: { id: episodeRecord.id },
          data: {
            videoUrl: url,
            streamSource: source,
            streamExpiresAt: expiresAt
          }
        });
      } else {
        // El episodio no está en BD aún — contenido no sincronizado con TMDB
        console.warn(`${label} → episodio no encontrado en BD`);
      }

    } else {
      // ── Película: guarda en Content.videoUrl ───────────────────────────
      // Content.tmdbId es String? @unique — busca directo
      await prisma.content.update({
        where: { tmdbId },
        data: {
          videoUrl: url,
          streamSource: source,
          streamExpiresAt: expiresAt
        }
      });
    }

    // Usa ScrapeLog que ya tenías en el schema
    await prisma.scrapeLog.create({
      data: {
        targetUrl: `${type}/${tmdbId}`,
        success: true,
        streamUrl: url,
        duration
      }
    }).catch(() => {});

    await prisma.scrapeJob.update({
      where: { tmdbId_type_season_episode: { tmdbId, type, season, episode } },
      data: { status: 'done', error: null }
    }).catch(() => {});

    console.log(`${label} → OK en ${duration}ms (${source})`);
    return { url, source };

  } catch (error) {
    const duration = Date.now() - startAt;
    console.error(`${label} → FALLÓ: ${error.message}`);

    // Usa ScrapeLog y BrokenLink que ya tenías
    await prisma.scrapeLog.create({
      data: {
        targetUrl: `${type}/${tmdbId}`,
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
      data: { status: 'failed', error: error.message }
    }).catch(() => {});

    throw error;
  }
}

// ─── UTILS ───────────────────────────────────────────────────────────────────
function extractDomain(url) {
  try { return new URL(url).hostname; } catch (_) { return 'unknown'; }
}

function getQueueStats() {
  return { running, pending: pending.length };
}

module.exports = { enqueue, getQueueStats };
