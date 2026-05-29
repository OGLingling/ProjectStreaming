// services/scrape_queue.js
// Cola en memoria — sin Redis, sin costo extra.
// Usa los modelos Content y Episode que ya existen en tu schema.

const { PrismaClient } = require('@prisma/client');
const VideoScraper = require('./scraper_service');
const { validateM3u8Url } = require('./stream_validator');
const ContentService = require('./content_service');

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

function normalizeStreamSource(source) {
  const url = typeof source === 'string' ? source : source?.url;
  if (!url) return null;
  return {
    url,
    subtitleUrl: source?.subtitleUrl || source?.subtitle_url || null,
    subtitleLanguage: source?.subtitleLanguage || source?.subtitle_language || 'es-419',
    subtitleLabel: source?.subtitleLabel || source?.subtitle_label || 'Espanol Latino',
    provider: source?.provider || null
  };
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

  let primaryUrl = null;
  let allCandidates = [];
  let source = null;
  let streamType = null;
  let selectedSource = null;
  let expiresAt = null;
  let duration = 0;

  const maxAttempts = 5;
  let attempts = 0;
  const excludedUrls = new Set();

  while (attempts < maxAttempts) {
    attempts++;
    console.log(`${label} → Intento de extracción y validación de streaming ${attempts}/${maxAttempts}`);

    try {
      // Limpiar el cache del scraper para asegurar una nueva búsqueda
      VideoScraper.clearCache({ tmdbId, type, season, episode });

      const result = await VideoScraper.extractStreamUrl({ tmdbId, type, season, episode });

      if (!result.success || !result.candidates?.length) {
        throw new Error('No se encontró ninguna URL de streaming en este intento.');
      }

      // Filtrar candidatos ya conocidos como caídos o descartados
      const enrichedSources = Array.isArray(result.sources)
        ? result.sources.map(normalizeStreamSource).filter(Boolean)
        : [];
      const rawSources = enrichedSources.length > 0
        ? enrichedSources
        : result.candidates.map((url) => normalizeStreamSource(url)).filter(Boolean);
      const validSources = rawSources.filter((item) => !excludedUrls.has(item.url));
      const validCandidates = validSources.map((item) => item.url);

      if (validCandidates.length === 0) {
        console.warn(`${label} → Todos los candidatos de este intento ya están descartados.`);
        throw new Error('Todos los candidatos están caídos o ya fueron descartados.');
      }

      allCandidates = validCandidates;
      selectedSource = validSources.find((item) => item.subtitleUrl) || validSources[0];
      primaryUrl = selectedSource.url;
      source = extractDomain(primaryUrl);
      streamType = detectStreamType(primaryUrl);
      expiresAt = new Date(Date.now() + URL_TTL_MS);
      duration = Date.now() - startAt;

      // ── Registro temporal de auditoría en ScrapeLog ────────────────────────
      const logRecord = await prisma.scrapeLog.create({
        data: {
          targetUrl: `${type}/${tmdbId}${isTV ? `/${season}/${episode}` : ''}`,
          success: true,
          streamUrl: primaryUrl,
          duration
        }
      }).catch((e) => {
        console.error(`[queue] Error creando ScrapeLog temporal: ${e.message}`);
        return null;
      });

      console.log(`${label} → Iniciando validación HTTP para: ${primaryUrl}`);
      const isValid = await validateM3u8Url(primaryUrl);

      if (isValid) {
        // SI LA URL FUNCIONA: Mantén el registro y procede a guardarlo de forma definitiva
        console.log(`${label} → ✅ URL válida y activa. Conservando log ID: ${logRecord ? logRecord.id : 'N/A'}`);

        if (isTV) {
          // ── Serie: guarda en Episode.videoUrl ─────────────────────────────
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
                streamExpiresAt: expiresAt,
                subtitleUrl: selectedSource.subtitleUrl || undefined,
                subtitleLanguage: selectedSource.subtitleLanguage || undefined,
                subtitleLabel: selectedSource.subtitleLabel || undefined
              }
            });
            console.log(`${label} → Episodio actualizado definitivamente (${streamType}): ${primaryUrl.substring(0, 70)}...`);
          } else {
            console.warn(`${label} → episodio no encontrado en BD (no sincronizado con TMDB)`);
          }

        } else {
          // ── Película: guarda en Content.videoUrl ───────────────────────────
          await ContentService.importFromTMDB(tmdbId, 'movie');
          await prisma.content.update({
            where: { tmdbId },
            data: {
              videoUrl: primaryUrl,
              streamSource: source,
              streamExpiresAt: expiresAt,
              subtitleUrl: selectedSource.subtitleUrl || undefined,
              subtitleLanguage: selectedSource.subtitleLanguage || undefined,
              subtitleLabel: selectedSource.subtitleLabel || undefined
            }
          });
          console.log(`${label} → Película actualizada definitivamente (${streamType}): ${primaryUrl.substring(0, 70)}...`);
        }

        await prisma.scrapeJob.update({
          where: { tmdbId_type_season_episode: { tmdbId, type, season, episode } },
          data: { status: 'done', error: null, updatedAt: new Date() }
        }).catch(() => {});

        console.log(`${label} → OK en ${duration}ms (fuente: ${source})`);
        return {
          url: primaryUrl,
          source,
          allCandidates,
          streamType,
          duration,
          subtitleUrl: selectedSource.subtitleUrl || null,
          subtitleLanguage: selectedSource.subtitleLanguage || null,
          subtitleLabel: selectedSource.subtitleLabel || null
        };

      } else {
        // SI LA URL NO REPRODUCE/ESTÁ CAÍDA: Elimina esa URL inmediatamente del log y descártala
        console.warn(`${label} → ❌ URL caída o inválida. Eliminando del log y descartando.`);

        if (logRecord) {
          await prisma.scrapeLog.delete({
            where: { id: logRecord.id }
          }).catch((err) => {
            console.error(`[queue] Error al eliminar log temporal: ${err.message}`);
          });
        }

        // Registrar en BrokenLink
        await prisma.brokenLink.create({
          data: {
            url: primaryUrl,
            error: 'Fallo validación HLS: status != 200 o sin cabecera #EXTM3U',
            provider: source
          }
        }).catch(() => {});

        // Descartar esta URL de futuros intentos de este ciclo
        excludedUrls.add(primaryUrl);
        
        // Continúa al siguiente intento de búsqueda
      }

    } catch (innerError) {
      console.warn(`${label} → Falló intento ${attempts} en el bucle: ${innerError.message}`);
      // Agregar error a los logs
      await prisma.brokenLink.create({
        data: {
          url: `${type}/${tmdbId}${isTV ? ` S${season}E${episode}` : ''}`,
          error: `Intento ${attempts} fallido: ${innerError.message}`,
          provider: 'queue_decision_loop'
        }
      }).catch(() => {});

      // Esperar brevemente antes de reintentar si el error fue de red/antivirus
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }

  // Si salimos del bucle sin retornar una URL válida
  const finalErrorMsg = 'Todas las URLs encontradas están caídas, no reproducen o el scraper no pudo hallar enlaces válidos.';
  duration = Date.now() - startAt;
  console.error(`${label} → Bucle de reintento agotado sin éxito: ${finalErrorMsg}`);

  await prisma.scrapeLog.create({
    data: {
      targetUrl: `${type}/${tmdbId}${isTV ? `/${season}/${episode}` : ''}`,
      success: false,
      error: finalErrorMsg,
      duration
    }
  }).catch(() => {});

  await prisma.scrapeJob.update({
    where: { tmdbId_type_season_episode: { tmdbId, type, season, episode } },
    data: { status: 'failed', error: finalErrorMsg, updatedAt: new Date() }
  }).catch(() => {});

  throw new Error(finalErrorMsg);
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
