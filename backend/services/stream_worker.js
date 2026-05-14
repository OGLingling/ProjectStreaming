// services/stream_worker.js
// Refresca automáticamente las URLs que están por vencer.
// Usa Content.streamExpiresAt y Episode.streamExpiresAt del schema.

const { PrismaClient } = require('@prisma/client');
const { enqueue, getQueueStats } = require('./scrape_queue');

const prisma = new PrismaClient();

// Refresca si le quedan menos de 2 horas (configurable)
const REFRESH_THRESHOLD_MS = Number(process.env.STREAM_REFRESH_THRESHOLD_MS) || 2 * 60 * 60 * 1000;

// Corre cada 30 minutos (configurable)
const INTERVAL_MS = Number(process.env.WORKER_INTERVAL_MS) || 30 * 60 * 1000;

// Máximo de items a refrescar por ciclo (evita saturar en BD grande)
const BATCH_SIZE = Number(process.env.WORKER_BATCH_SIZE) || 10;

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
    // ── 1. Películas: vencidas, próximas a vencer o sin stream ──────────────
    const movies = await prisma.content.findMany({
      where: {
        type: 'movie',
        tmdbId: { not: null },
        OR: [
          // Nunca se scrapearon
          { videoUrl: null },
          // Ya vencieron
          { streamExpiresAt: { lt: new Date() } },
          // Están por vencer (dentro del umbral)
          { streamExpiresAt: { lt: threshold } }
        ]
      },
      select: { tmdbId: true, videoUrl: true, streamExpiresAt: true, title: true },
      take: BATCH_SIZE,
      orderBy: [
        // Primero las que nunca se scrapearon, luego las más próximas a vencer
        { streamExpiresAt: 'asc' }
      ]
    });
    moviesFound = movies.length;

    // ── 2. Episodios: mismo criterio ─────────────────────────────────────────
    const episodes = await prisma.episode.findMany({
      where: {
        OR: [
          { videoUrl: null },
          { streamExpiresAt: { lt: new Date() } },
          { streamExpiresAt: { lt: threshold } }
        ],
        // Solo episodios cuyo contenido padre tenga tmdbId
        season: {
          content: { tmdbId: { not: null } }
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

    // Loguear qué se va a refrescar
    for (const m of movies) {
      const status = !m.videoUrl ? 'sin stream' : m.streamExpiresAt < new Date() ? 'vencida' : 'próxima a vencer';
      console.log(`[worker]   📽 ${m.title || m.tmdbId} [${status}]`);
    }

    // ── 3. Encolar con force=true para saltear verificación de caché ─────────
    const jobs = [
      ...movies.map(({ tmdbId }) =>
        enqueue(tmdbId, 'movie', 1, 1, true) // force=true
      ),
      ...episodes
        .filter(ep => ep.season?.content?.tmdbId)
        .map(ep =>
          enqueue(
            ep.season.content.tmdbId,
            'tv',
            ep.season.seasonNumber,
            ep.episodeNumber,
            true // force=true
          )
        )
    ];

    const results = await Promise.allSettled(jobs);
    ok   = results.filter(r => r.status === 'fulfilled').length;
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
  console.log(`[worker] Iniciado — intervalo: ${INTERVAL_MS / 60000} min | umbral refresh: ${REFRESH_THRESHOLD_MS / 3600000}h | batch: ${BATCH_SIZE}`);

  // Primer ciclo 90s después del arranque (da tiempo al servidor a estar listo)
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

/** Fuerza un ciclo inmediato (para uso desde endpoint admin) */
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
    batchSize: BATCH_SIZE
  };
}

module.exports = { startWorker, stopWorker, triggerManualCycle, getWorkerStatus };
