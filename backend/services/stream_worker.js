// services/stream_worker.js
// Refresca automáticamente las URLs que están por vencer.
// Usa Content.streamExpiresAt y Episode.streamExpiresAt de tu schema.

const { PrismaClient } = require('@prisma/client');
const { enqueue, getQueueStats } = require('./scrape_queue');

const prisma = new PrismaClient();

// Refresca si le quedan menos de 2 horas de vida
const REFRESH_THRESHOLD_MS = 2 * 60 * 60 * 1000;

// Corre cada 30 minutos
const INTERVAL_MS = 30 * 60 * 1000;

let timer = null;
let isRunning = false;

async function refreshCycle() {
  if (isRunning) return;
  isRunning = true;

  const stats = getQueueStats();
  console.log(`[worker] Ciclo iniciado | pendientes: ${stats.pending} | corriendo: ${stats.running}`);

  try {
    const threshold = new Date(Date.now() + REFRESH_THRESHOLD_MS);

    // ── Películas por vencer ────────────────────────────────────────────────
    const movies = await prisma.content.findMany({
      where: {
        type: 'movie',
        tmdbId: { not: null },
        // Vence pronto O nunca se le hizo scraping pero tiene contenido
        OR: [
          { streamExpiresAt: { lt: threshold } },
          { streamExpiresAt: null, videoUrl: null }
        ]
      },
      select: { tmdbId: true },
      take: 10,
      orderBy: { streamExpiresAt: 'asc' }
    });

    // ── Episodios por vencer ────────────────────────────────────────────────
    const episodes = await prisma.episode.findMany({
      where: {
        OR: [
          { streamExpiresAt: { lt: threshold } },
          { streamExpiresAt: null, videoUrl: null }
        ]
      },
      select: {
        episodeNumber: true,
        season: {
          select: {
            seasonNumber: true,
            content: { select: { tmdbId: true } }
          }
        }
      },
      take: 10,
      orderBy: { streamExpiresAt: 'asc' }
    });

    const total = movies.length + episodes.length;
    if (total === 0) {
      console.log('[worker] Todo vigente');
      return;
    }

    console.log(`[worker] ${movies.length} películas + ${episodes.length} episodios para refrescar`);

    // Encola todo — la cola controla la concurrencia
    const jobs = [
      ...movies.map(({ tmdbId }) => enqueue(tmdbId, 'movie')),
      ...episodes
        .filter(ep => ep.season?.content?.tmdbId)
        .map(ep => enqueue(
          ep.season.content.tmdbId,
          'tv',
          ep.season.seasonNumber,
          ep.episodeNumber
        ))
    ];

    const results = await Promise.allSettled(jobs);
    const ok = results.filter(r => r.status === 'fulfilled').length;
    const fail = results.filter(r => r.status === 'rejected').length;
    console.log(`[worker] Ciclo terminado | OK: ${ok} | Fallidos: ${fail}`);

  } catch (error) {
    console.error('[worker] Error en ciclo:', error.message);
  } finally {
    isRunning = false;
  }
}

function startWorker() {
  if (timer) return;
  console.log('[worker] Iniciado — intervalo: 30 minutos');
  // Espera 90 segundos para que el servidor arranque limpio
  setTimeout(() => {
    refreshCycle();
    timer = setInterval(refreshCycle, INTERVAL_MS);
  }, 90 * 1000);
}

function stopWorker() {
  if (timer) { clearInterval(timer); timer = null; }
}

module.exports = { startWorker, stopWorker };
