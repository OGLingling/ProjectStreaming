// services/stream_worker.js

const { PrismaClient } = require('@prisma/client');
const { enqueue, getQueueStats } = require('./scrape_queue');

const prisma = new PrismaClient();

const REFRESH_THRESHOLD_MS = Number(process.env.STREAM_REFRESH_THRESHOLD_MS) || 2 * 60 * 60 * 1000;
const INTERVAL_MS = Number(process.env.WORKER_INTERVAL_MS) || 30 * 60 * 1000;
const BATCH_SIZE = Number(process.env.WORKER_BATCH_SIZE) || 10;

// Máximo de intentos fallidos antes de dejar de reintentar automáticamente
// El scrape manual (force-refresh) sigue funcionando igual
const MAX_FAILED_ATTEMPTS = 3;

let timer = null;
let isRunning = false;
let lastCycleAt = null;
let lastCycleStats = null;

// ─── CICLO PRINCIPAL ─────────────────────────────────────────────────────────
async function refreshCycle() {
  if (isRunning) {
    console.log('[worker] Ciclo anterior aún en curso, saltando');
    return;
  }
  isRunning = true;
  lastCycleAt = new Date();

  const queueStats = getQueueStats();
  console.log(`[worker] ── Ciclo iniciado ${lastCycleAt.toISOString()} | pendientes: ${queueStats.pending} | corriendo: ${queueStats.running}`);

  const threshold = new Date(Date.now() + REFRESH_THRESHOLD_MS);
  let moviesFound = 0, episodesFound = 0, ok = 0, fail = 0;

  try {
    // ── FIX: obtener tmdbIds que ya fallaron demasiado — no reintentar ────────
    // Evita que el worker sature la cola con contenido que siempre falla
    const [failedMovieIds, failedTvIds] = await Promise.all([
      prisma.scrapeJob.findMany({
        where: { type: 'movie', status: 'failed', attempts: { gte: MAX_FAILED_ATTEMPTS } },
        select: { tmdbId: true }
      }).then(jobs => jobs.map(j => j.tmdbId)).catch(() => []),

      prisma.scrapeJob.findMany({
        where: { type: 'tv', status: 'failed', attempts: { gte: MAX_FAILED_ATTEMPTS } },
        select: { tmdbId: true }
      }).then(jobs => jobs.map(j => j.tmdbId)).catch(() => [])
    ]);

    if (failedMovieIds.length > 0) {
      console.log(`[worker] Excluyendo ${failedMovieIds.length} película(s) con ${MAX_FAILED_ATTEMPTS}+ fallos`);
    }

    // ── 1. Películas por refrescar ────────────────────────────────────────────
    const movies = await prisma.content.findMany({
      where: {
        type: 'movie',
        tmdbId: {
          not: null,
          // FIX: excluir las que ya fallaron demasiadas veces
          ...(failedMovieIds.length > 0 ? { notIn: failedMovieIds } : {})
        },
        OR: [
          { videoUrl: null },
          { streamExpiresAt: { lt: new Date() } },
          { streamExpiresAt: { lt: threshold } }
        ]
      },
      select: { tmdbId: true, videoUrl: true, streamExpiresAt: true, title: true },
      take: BATCH_SIZE,
      orderBy: { streamExpiresAt: 'asc' }
    });
    moviesFound = movies.length;

    // ── 2. Episodios por refrescar ────────────────────────────────────────────
    const episodes = await prisma.episode.findMany({
      where: {
        OR: [
          { videoUrl: null },
          { streamExpiresAt: { lt: new Date() } },
          { streamExpiresAt: { lt: threshold } }
        ],
        season: {
          content: {
            tmdbId: {
              not: null,
              // FIX: excluir series que siempre fallan
              ...(failedTvIds.length > 0 ? { notIn: failedTvIds } : {})
            }
          }
        }
      },
      select: {
        episodeNumber: true,
        streamExpiresAt: true,
        season: {
          select: {
            seasonNumber: true,
            content: { select: { tmdbId: true, title: true } }
          }
        }
      },
      take: BATCH_SIZE,
      orderBy: { streamExpiresAt: 'asc' }
    });
    episodesFound = episodes.length;

    const total = moviesFound + episodesFound;
    if (total === 0) {
      console.log('[worker] ✅ Todo vigente — nada que refrescar');
      lastCycleStats = { ok: 0, fail: 0, moviesFound: 0, episodesFound: 0 };
      return;
    }

    console.log(`[worker] 🔄 ${moviesFound} película(s) + ${episodesFound} episodio(s) para refrescar`);

    for (const m of movies) {
      const status = !m.videoUrl
        ? 'sin stream'
        : m.streamExpiresAt < new Date()
          ? 'vencida'
          : 'próxima a vencer';
      console.log(`[worker]   📽 ${m.title || m.tmdbId} [${status}]`);
    }

    // ── 3. Encolar con force=true ─────────────────────────────────────────────
    const jobs = [
      ...movies.map(({ tmdbId }) =>
        enqueue(tmdbId, 'movie', 1, 1, true)
      ),
      ...episodes
        .filter(ep => ep.season?.content?.tmdbId)
        .map(ep =>
          enqueue(
            ep.season.content.tmdbId,
            'tv',
            ep.season.seasonNumber,
            ep.episodeNumber,
            true
          )
        )
    ];

    const results = await Promise.allSettled(jobs);
    ok = results.filter(r => r.status === 'fulfilled').length;
    fail = results.filter(r => r.status === 'rejected').length;

    if (fail > 0) {
      results
        .filter(r => r.status === 'rejected')
        .forEach(r => console.warn('[worker] ⚠ Fallo en job:', r.reason?.message));
    }

    console.log(`[worker] ── Ciclo terminado | ✅ OK: ${ok} | ❌ Fallidos: ${fail}`);

  } catch (error) {
    console.error('[worker] ❌ Error crítico en ciclo:', error.message);
  } finally {
    lastCycleStats = { ok, fail, moviesFound, episodesFound };
    isRunning = false;
  }
}

// ─── API PÚBLICA ─────────────────────────────────────────────────────────────
function startWorker() {
  if (timer) return;
  console.log(`[worker] Iniciado — intervalo: ${INTERVAL_MS / 60000} min | umbral: ${REFRESH_THRESHOLD_MS / 3600000}h | batch: ${BATCH_SIZE}`);
  setTimeout(() => {
    refreshCycle();
    timer = setInterval(refreshCycle, INTERVAL_MS);
  }, 90 * 1000);
}

function stopWorker() {
  if (timer) {
    clearInterval(timer);
    timer = null;
    console.log('[worker] Detenido');
  }
}

async function triggerManualCycle() {
  if (isRunning) return { skipped: true, reason: 'already_running' };
  await refreshCycle();
  return { skipped: false, stats: lastCycleStats };
}

function getWorkerStatus() {
  return {
    active: !!timer,
    running: isRunning,
    lastCycleAt: lastCycleAt?.toISOString() || null,
    lastCycleStats,
    intervalMs: INTERVAL_MS,
    refreshThresholdMs: REFRESH_THRESHOLD_MS,
    batchSize: BATCH_SIZE,
    maxFailedAttempts: MAX_FAILED_ATTEMPTS
  };
}

module.exports = { startWorker, stopWorker, triggerManualCycle, getWorkerStatus };