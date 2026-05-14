// services/scrape_queue.js
// MEJORA: Cola con prioridades + límite de memoria + reintentos inteligentes

const { PrismaClient } = require('@prisma/client');
const VideoScraper = require('./scraper_service');

const prisma = new PrismaClient();

const MAX_CONCURRENT = Number(process.env.SCRAPER_CONCURRENT) || 2;
const URL_TTL_MS = 10 * 60 * 60 * 1000; // 10 horas
const MAX_RETRIES = 3;
const MAX_QUEUE_SIZE = 100; // Evitar memory leaks

// Colas por prioridad
const queues = {
  high: [],    // Expira en < 1 hora o error previo
  medium: [],  // Expira en < 6 horas
  low: []      // Nuevo contenido o refresh preventivo
};

let running = 0;
let totalProcessed = 0;
let totalFailed = 0;

// ─── ENQUEUE CON PRIORIDAD ──────────────────────────────────────────────────
function enqueue(tmdbId, type, season = 1, episode = 1, priority = 'medium') {
  // Validar tamaño de cola
  const totalPending = Object.values(queues).reduce((sum, q) => sum + q.length, 0);
  if (totalPending >= MAX_QUEUE_SIZE) {
    console.warn(`[queue] Cola llena (${totalPending}), rechazando: ${type}/${tmdbId}`);
    return Promise.reject(new Error('Cola saturada, intenta más tarde'));
  }

  return new Promise((resolve, reject) => {
    const job = {
      tmdbId: String(tmdbId),
      type: String(type),
      season: Number(season),
      episode: Number(episode),
      priority,
      retries: 0,
      resolve,
      reject,
      createdAt: Date.now()
    };

    queues[priority].push(job);
    console.log(`[queue] Encolado [${priority}]: ${type}/${tmdbId} (total: ${totalPending + 1})`);

    // Procesar inmediatamente si hay capacidad
    tick();
  });
}

// ─── TICK: Procesa siguiente job ────────────────────────────────────────────
function tick() {
  if (running >= MAX_CONCURRENT) return;

  // Buscar en orden de prioridad
  const job = queues.high.shift() || queues.medium.shift() || queues.low.shift();

  if (!job) return;

  running++;

  processJob(job)
    .then(result => {
      totalProcessed++;
      job.resolve(result);
    })
    .catch(error => {
      totalFailed++;

      // Reintentar con backoff exponencial
      if (job.retries < MAX_RETRIES) {
        job.retries++;
        const delay = Math.pow(2, job.retries) * 1000; // 1s, 2s, 4s
        console.log(`[queue] Reintento ${job.retries}/${MAX_RETRIES} en ${delay}ms: ${job.type}/${job.tmdbId}`);

        setTimeout(() => {
          queues.high.unshift(job); // Prioridad alta para reintentos
          tick();
        }, delay);
      } else {
        job.reject(error);
      }
    })
    .finally(() => {
      running--;
      tick(); // Procesar siguiente
    });
}

// ─── PROCESS JOB ────────────────────────────────────────────────────────────
async function processJob(job) {
  const { tmdbId, type, season, episode } = job;
  const isTV = type === 'tv';
  const label = `[${job.priority}] ${type}/${tmdbId}${isTV ? ` S${season}E${episode}` : ''}`;
  const startAt = Date.now();

  console.log(`${label} → Iniciando scrape (intento ${job.retries + 1})`);

  // Verificar si ya existe en BD y está vigente
  const existing = await checkExistingStream(tmdbId, type, season, episode);
  if (existing && new Date(existing.expiresAt) > new Date(Date.now() + 3600000)) {
    console.log(`${label} → Ya vigente en BD, omitiendo`);
    return { url: existing.url, source: 'cache' };
  }

  try {
    const result = await VideoScraper.extractStreamUrl({
      tmdbId,
      type,
      season,
      episode
    });

    if (!result.success || !result.candidates?.[0]) {
      throw new Error('No se encontró ninguna URL válida');
    }

    const url = result.candidates[0];
    const source = extractDomain(url);
    const expiresAt = new Date(Date.now() + URL_TTL_MS);
    const duration = Date.now() - startAt;

    // Guardar en BD según tipo
    await saveStreamToDB(tmdbId, type, season, episode, url, source, expiresAt);

    // Registrar éxito
    await prisma.scrapeLog.create({
      data: {
        targetUrl: `${type}/${tmdbId}`,
        success: true,
        streamUrl: url,
        duration,
        provider: source
      }
    }).catch(() => { });

    console.log(`${label} → ✅ OK en ${duration}ms (${source})`);
    return { url, source, expiresAt };

  } catch (error) {
    const duration = Date.now() - startAt;
    console.error(`${label} → ❌ FALLÓ: ${error.message}`);

    // Registrar error
    await prisma.scrapeLog.create({
      data: {
        targetUrl: `${type}/${tmdbId}`,
        success: false,
        error: error.message,
        duration
      }
    }).catch(() => { });

    await prisma.brokenLink.create({
      data: {
        url: `${type}/${tmdbId}`,
        error: error.message,
        provider: 'vidsrc'
      }
    }).catch(() => { });

    throw error;
  }
}

// ─── HELPERS ────────────────────────────────────────────────────────────────
async function checkExistingStream(tmdbId, type, season, episode) {
  if (type === 'tv') {
    const ep = await prisma.episode.findFirst({
      where: {
        episodeNumber: episode,
        season: {
          seasonNumber: season,
          content: { tmdbId }
        }
      },
      select: { videoUrl: true, streamExpiresAt: true }
    }).catch(() => null);

    if (ep?.videoUrl && ep.streamExpiresAt) {
      return { url: ep.videoUrl, expiresAt: ep.streamExpiresAt };
    }
  } else {
    const content = await prisma.content.findUnique({
      where: { tmdbId },
      select: { videoUrl: true, streamExpiresAt: true }
    }).catch(() => null);

    if (content?.videoUrl && content.streamExpiresAt) {
      return { url: content.videoUrl, expiresAt: content.streamExpiresAt };
    }
  }

  return null;
}

async function saveStreamToDB(tmdbId, type, season, episode, url, source, expiresAt) {
  if (type === 'tv') {
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
          videoUrl: url,
          streamSource: source,
          streamExpiresAt: expiresAt
        }
      });
    }
  } else {
    await prisma.content.update({
      where: { tmdbId },
      data: {
        videoUrl: url,
        streamSource: source,
        streamExpiresAt: expiresAt
      }
    });
  }
}

function extractDomain(url) {
  try { return new URL(url).hostname; }
  catch (_) { return 'unknown'; }
}

// ─── STATS ──────────────────────────────────────────────────────────────────
function getQueueStats() {
  return {
    running,
    pending: {
      high: queues.high.length,
      medium: queues.medium.length,
      low: queues.low.length,
      total: queues.high.length + queues.medium.length + queues.low.length
    },
    processed: totalProcessed,
    failed: totalFailed,
    maxConcurrent: MAX_CONCURRENT
  };
}

// Limpiar jobs antiguos cada 5 minutos
setInterval(() => {
  const now = Date.now();
  const MAX_AGE = 10 * 60 * 1000; // 10 minutos máximo en cola

  Object.keys(queues).forEach(priority => {
    queues[priority] = queues[priority].filter(job => {
      if (now - job.createdAt > MAX_AGE) {
        job.reject(new Error('Job expiró en cola'));
        return false;
      }
      return true;
    });
  });
}, 5 * 60 * 1000);

module.exports = { enqueue, getQueueStats };