// services/stream_worker.js
// MEJORA: Worker que detecta prioridad según tiempo de expiración

const { PrismaClient } = require('@prisma/client');
const { enqueue, getQueueStats } = require('./scrape_queue');

const prisma = new PrismaClient();

// Umbrales de prioridad
const URGENT_THRESHOLD = 60 * 60 * 1000;      // 1 hora
const WARNING_THRESHOLD = 6 * 60 * 60 * 1000;  // 6 horas
const PREVENTIVE_THRESHOLD = 24 * 60 * 60 * 1000; // 24 horas

const INTERVAL_MS = 30 * 60 * 1000; // 30 minutos

let timer = null;
let isRunning = false;
let cyclesCompleted = 0;

async function refreshCycle() {
  if (isRunning) {
    console.log('[worker] Ciclo anterior aún ejecutándose, omitiendo');
    return;
  }

  isRunning = true;
  cyclesCompleted++;

  const stats = getQueueStats();
  console.log(`[worker] 🔄 Ciclo #${cyclesCompleted} | Cola: ${stats.pending.total} pendientes | ${stats.running} en proceso`);

  try {
    const now = new Date();

    // ── Buscar contenido que necesita refresh ────────────────────────────
    const [urgent, warning, preventive] = await Promise.all([
      findExpiringContent(now, URGENT_THRESHOLD, 20),
      findExpiringContent(now, WARNING_THRESHOLD, 15),
      findExpiringContent(now, PREVENTIVE_THRESHOLD, 10)
    ]);

    const total = urgent.total + warning.total + preventive.total;

    if (total === 0) {
      console.log('[worker] ✅ Todo vigente, nada que renovar');
      return;
    }

    console.log(`[worker] 📊 Encontrados: ${urgent.total} urgentes | ${warning.total} warning | ${preventive.total} preventivos`);

    // Encolar con prioridades
    const jobs = [];

    // Urgentes primero
    urgent.movies.forEach(m => {
      jobs.push(enqueue(m.tmdbId, 'movie', 1, 1, 'high'));
    });
    urgent.episodes.forEach(ep => {
      if (ep.season?.content?.tmdbId) {
        jobs.push(enqueue(
          ep.season.content.tmdbId, 'tv',
          ep.season.seasonNumber, ep.episodeNumber,
          'high'
        ));
      }
    });

    // Warning
    warning.movies.forEach(m => {
      jobs.push(enqueue(m.tmdbId, 'movie', 1, 1, 'medium'));
    });
    warning.episodes.forEach(ep => {
      if (ep.season?.content?.tmdbId) {
        jobs.push(enqueue(
          ep.season.content.tmdbId, 'tv',
          ep.season.seasonNumber, ep.episodeNumber,
          'medium'
        ));
      }
    });

    // Preventivos
    preventive.movies.forEach(m => {
      jobs.push(enqueue(m.tmdbId, 'movie', 1, 1, 'low'));
    });
    preventive.episodes.forEach(ep => {
      if (ep.season?.content?.tmdbId) {
        jobs.push(enqueue(
          ep.season.content.tmdbId, 'tv',
          ep.season.seasonNumber, ep.episodeNumber,
          'low'
        ));
      }
    });

    // Esperar a que todos los jobs se completen (con timeout)
    const results = await Promise.allSettled(
      jobs.map(job => Promise.race([
        job,
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Timeout en cola')), 120000)
        )
      ]))
    );

    const ok = results.filter(r => r.status === 'fulfilled').length;
    const fail = results.filter(r => r.status === 'rejected').length;

    console.log(`[worker] ✅ Ciclo completado | OK: ${ok} | Fallidos: ${fail}`);

  } catch (error) {
    console.error('[worker] ❌ Error en ciclo:', error.message);
  } finally {
    isRunning = false;
  }
}

// ─── FIND EXPIRING CONTENT ──────────────────────────────────────────────────
async function findExpiringContent(now, thresholdMs, limit) {
  const threshold = new Date(now.getTime() + thresholdMs);

  const [movies, episodes] = await Promise.all([
    // Películas
    prisma.content.findMany({
      where: {
        type: 'movie',
        tmdbId: { not: null },
        OR: [
          {
            streamExpiresAt: {
              lt: threshold,
              gt: now // Solo las que aún no expiraron
            }
          },
          {
            streamExpiresAt: null,
            videoUrl: null
          }
        ]
      },
      select: { tmdbId: true, streamExpiresAt: true },
      take: limit,
      orderBy: { streamExpiresAt: 'asc' }
    }),

    // Episodios
    prisma.episode.findMany({
      where: {
        OR: [
          {
            streamExpiresAt: {
              lt: threshold,
              gt: now
            }
          },
          {
            streamExpiresAt: null,
            videoUrl: null
          }
        ]
      },
      select: {
        episodeNumber: true,
        streamExpiresAt: true,
        season: {
          select: {
            seasonNumber: true,
            content: { select: { tmdbId: true } }
          }
        }
      },
      take: limit,
      orderBy: { streamExpiresAt: 'asc' }
    })
  ]);

  return {
    movies,
    episodes,
    total: movies.length + episodes.length
  };
}

// ─── START / STOP ───────────────────────────────────────────────────────────
function startWorker() {
  if (timer) {
    console.log('[worker] Ya está corriendo');
    return;
  }

  console.log('[worker] 🚀 Iniciado — intervalo: 30 minutos');

  // Primer ciclo después de 1 minuto (para que el servidor esté listo)
  setTimeout(() => {
    refreshCycle();
    timer = setInterval(refreshCycle, INTERVAL_MS);
  }, 60000);
}

function stopWorker() {
  if (timer) {
    clearInterval(timer);
    timer = null;
    console.log('[worker] ⏹️ Detenido');
  }
}

// Si quieres health check simple sin archivo extra:
async function getWorkerHealth() {
  try {
    const [activeStreams, totalContent] = await Promise.all([
      prisma.content.count({
        where: {
          videoUrl: { not: null },
          streamExpiresAt: { gt: new Date() }
        }
      }),
      prisma.content.count()
    ]);

    return {
      status: 'active',
      cyclesCompleted,
      isRunning,
      activeStreams,
      totalContent,
      coverage: totalContent > 0 ? ((activeStreams / totalContent) * 100).toFixed(1) + '%' : '0%',
      queue: getQueueStats(),
      uptime: process.uptime()
    };
  } catch (error) {
    return {
      status: 'error',
      error: error.message
    };
  }
}

module.exports = { startWorker, stopWorker, getWorkerHealth };