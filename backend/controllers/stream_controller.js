// controllers/stream_controller.js

const axios = require('axios');
const { PrismaClient } = require('@prisma/client');
const { createStreamSession, getStreamSession } = require('../services/stream_session_store');
const { enqueue, getQueueStats } = require('../services/scrape_queue');
const { triggerManualCycle, getWorkerStatus } = require('../services/stream_worker');

const prisma = new PrismaClient();

const MOBILE_USER_AGENT =
  'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

const isHttpUrl = (v) => /^https?:\/\//i.test(String(v || ''));
const encodeUrl = (url) => Buffer.from(url, 'utf8').toString('base64url');
const decodeUrl = (v) => Buffer.from(v, 'base64url').toString('utf8');

// ─── HEADERS ─────────────────────────────────────────────────────────────────
function buildHeaders(targetUrl, sourceUrl, custom = {}) {
  const targetOrigin = new URL(targetUrl).origin;
  const sourceOrigin = sourceUrl && isHttpUrl(sourceUrl)
    ? new URL(sourceUrl).origin : targetOrigin;
  return {
    'User-Agent': custom['User-Agent'] || MOBILE_USER_AGENT,
    'Referer': custom.Referer || `${sourceOrigin}/`,
    'Origin': custom.Origin || sourceOrigin,
    'Accept': custom.Accept || '*/*',
    'Accept-Language': custom['Accept-Language'] || 'es-ES,es;q=0.9'
  };
}

// ─── HLS PROXY REWRITE ───────────────────────────────────────────────────────
function absoluteUrl(base, maybe) {
  if (!maybe || maybe.startsWith('#')) return maybe;
  return new URL(maybe, base).toString();
}

function rewriteAttributeUris(line, baseUrl, sessionId, req) {
  return line.replace(/URI="([^"]+)"/g, (_, value) => {
    if (value.startsWith('data:') || value.startsWith('skd:')) return `URI="${value}"`;
    const abs = absoluteUrl(baseUrl, value);
    return `URI="${req.protocol}://${req.get('host')}/api/stream/${sessionId}/resource?u=${encodeUrl(abs)}"`;
  });
}

function rewritePlaylist(body, baseUrl, sessionId, req) {
  return body.split(/\r?\n/).map((rawLine) => {
    const line = rawLine.trim();
    if (!line) return rawLine;
    if (line.startsWith('#')) return rewriteAttributeUris(rawLine, baseUrl, sessionId, req);
    const abs = absoluteUrl(baseUrl, line);
    return `${req.protocol}://${req.get('host')}/api/stream/${sessionId}/resource?u=${encodeUrl(abs)}`;
  }).join('\n');
}

async function fetchUpstream(url, session, responseType = 'stream') {
  return axios.get(url, {
    responseType,
    timeout: 20000,
    maxRedirects: 5,
    headers: buildHeaders(url, session.sourceUrl, session.headers),
    validateStatus: (s) => s >= 200 && s < 500
  });
}

// ─── ENDPOINT PRINCIPAL: GET /api/stream/link ─────────────────────────────────
// Flutter llama esto para obtener la URL reproducible del stream.
//
// Query params:
//   tmdbId  — ID de TMDB (requerido)
//   type    — "movie" | "tv" (default: "movie")
//   season  — número de temporada (solo TV, default: 1)
//   episode — número de episodio (solo TV, default: 1)
//
// Respuesta exitosa:
//   { success: true, streamUrl: "https://...", expiresAt: "..." }
//
// Respuesta si está scrapeando (primera vez):
//   HTTP 503 + { success: false, error: "...", retryAfter: 15 }
async function getStreamLink(req, res) {
  const tmdbId = String(req.query.tmdbId || req.body?.tmdbId || '');
  const type   = String(req.query.type   || req.body?.type   || 'movie').toLowerCase();
  const season  = Number(req.query.season  || req.body?.season  || 1);
  const episode = Number(req.query.episode || req.body?.episode || 1);

  if (!tmdbId) {
    return res.status(400).json({ success: false, error: 'tmdbId requerido' });
  }

  // ── Paso 1: busca en BD ──────────────────────────────────────────────────
  let cachedUrl   = null;
  let isExpired   = false;
  const now       = new Date();

  if (type === 'tv') {
    const ep = await prisma.episode.findFirst({
      where: {
        episodeNumber: episode,
        season: { seasonNumber: season, content: { tmdbId } }
      },
      select: { videoUrl: true, streamExpiresAt: true }
    }).catch(() => null);

    if (ep?.videoUrl) {
      cachedUrl = ep.videoUrl;
      isExpired = !ep.streamExpiresAt || ep.streamExpiresAt <= now;
    }
  } else {
    const content = await prisma.content.findUnique({
      where: { tmdbId },
      select: { videoUrl: true, streamExpiresAt: true }
    }).catch(() => null);

    if (content?.videoUrl) {
      cachedUrl = content.videoUrl;
      isExpired = !content.streamExpiresAt || content.streamExpiresAt <= now;
    }
  }

  // ── Paso 2: URL vigente en BD → responder inmediatamente ─────────────────
  if (cachedUrl && !isExpired) {
    console.log(`[stream] ✅ BD hit (vigente): ${type}/${tmdbId}`);
    return registerAndRespond(req, res, cachedUrl);
  }

  // ── Paso 3: URL expirada → servir la vieja mientras se renueva en background
  if (cachedUrl && isExpired) {
    console.log(`[stream] ⏰ BD hit (expirada): ${type}/${tmdbId} — renovando en background`);
    // Renovación NO bloqueante: el cliente recibe la URL vieja de inmediato
    enqueue(tmdbId, type, season, episode, true).catch(err =>
      console.warn(`[stream] Renovación background fallida para ${tmdbId}:`, err.message)
    );
    return registerAndRespond(req, res, cachedUrl);
  }

  // ── Paso 4: no existe en BD → scrapear ahora (bloqueante) ────────────────
  console.log(`[stream] 🔍 BD miss: ${type}/${tmdbId} — scrapeando ahora`);

  try {
    const scraped = await enqueue(tmdbId, type, season, episode);
    return registerAndRespond(req, res, scraped.url);
  } catch (error) {
    console.error(`[stream] ❌ Scrape fallido para ${tmdbId}:`, error.message);
    return res.status(503).json({
      success: false,
      error: 'No se pudo obtener el stream. Intenta de nuevo en 15 segundos.',
      retryAfter: 15
    });
  }
}

// ─── CREA SESSION DE PROXY Y RESPONDE ────────────────────────────────────────
function registerAndRespond(req, res, targetUrl) {
  const isHls = targetUrl.toLowerCase().includes('.m3u8');
  const session = createStreamSession({ targetUrl, sourceUrl: null, headers: {} });
  const path = isHls ? 'master.m3u8' : 'source';

  return res.json({
    success: true,
    streamUrl: `${req.protocol}://${req.get('host')}/api/stream/${session.id}/${path}`,
    expiresAt: new Date(session.expiresAt).toISOString()
  });
}

// ─── ENDPOINT LEGACY: POST /api/stream/register ──────────────────────────────
async function registerStream(req, res) {
  const targetUrl = req.body?.url || req.query?.url;
  const sourceUrl = req.body?.sourceUrl || req.body?.referer || null;

  if (!isHttpUrl(targetUrl)) {
    return res.status(400).json({ success: false, error: 'URL de stream invalida' });
  }

  const headers = buildHeaders(targetUrl, sourceUrl, req.body?.headers || {});
  const session = createStreamSession({ targetUrl, sourceUrl, headers });
  const isHls = targetUrl.toLowerCase().includes('.m3u8');

  return res.json({
    success: true,
    streamId: session.id,
    streamUrl: `${req.protocol}://${req.get('host')}/api/stream/${session.id}/${isHls ? 'master.m3u8' : 'source'}`,
    expiresAt: new Date(session.expiresAt).toISOString()
  });
}

// ─── PROXY HLS ───────────────────────────────────────────────────────────────
async function getMasterPlaylist(req, res) {
  const session = getStreamSession(req.params.streamId);
  if (!session) return res.status(404).send('Stream session expired');
  return serveResource(req, res, session.targetUrl, session);
}

async function getSource(req, res) {
  const session = getStreamSession(req.params.streamId);
  if (!session) return res.status(404).send('Stream session expired');
  return serveResource(req, res, session.targetUrl, session);
}

async function getResource(req, res) {
  const session = getStreamSession(req.params.streamId);
  if (!session) return res.status(404).send('Stream session expired');
  let targetUrl;
  try { targetUrl = decodeUrl(req.query.u); } catch (_) {
    return res.status(400).send('Invalid resource URL');
  }
  if (!isHttpUrl(targetUrl)) return res.status(400).send('Invalid resource URL');
  return serveResource(req, res, targetUrl, session);
}

async function serveResource(req, res, targetUrl, session) {
  try {
    const upstream = await fetchUpstream(targetUrl, session, 'arraybuffer');
    const ct = String(upstream.headers['content-type'] || '').toLowerCase();
    const isPlaylist = targetUrl.toLowerCase().includes('.m3u8') ||
      ct.includes('mpegurl') || ct.includes('vnd.apple.mpegurl');

    res.set('Access-Control-Allow-Origin', '*');
    res.set('Cache-Control', 'no-store');

    if (upstream.status >= 400) return res.status(upstream.status).send(upstream.data);

    if (isPlaylist) {
      const text = Buffer.from(upstream.data).toString('utf8');
      res.set('Content-Type', 'application/vnd.apple.mpegurl');
      return res.send(rewritePlaylist(text, targetUrl, session.id, req));
    }

    if (ct) res.set('Content-Type', ct);
    return res.send(Buffer.from(upstream.data));
  } catch (error) {
    console.error('[stream] Proxy error:', error.message);
    return res.status(502).send('No se pudo obtener el recurso de video');
  }
}

// ─── STATUS: GET /api/stream/status ─────────────────────────────────────────
async function getStatus(req, res) {
  const queue  = getQueueStats();
  const worker = getWorkerStatus();
  const now    = new Date();

  const [
    totalMovies, moviesWithStream, moviesExpired, moviesNoStream,
    totalEpisodes, episodesWithStream, episodesExpired, episodesNoStream
  ] = await Promise.all([
    prisma.content.count({ where: { type: 'movie' } }),
    prisma.content.count({ where: { type: 'movie', videoUrl: { not: null }, streamExpiresAt: { gt: now } } }),
    prisma.content.count({ where: { type: 'movie', videoUrl: { not: null }, streamExpiresAt: { lt: now } } }),
    prisma.content.count({ where: { type: 'movie', videoUrl: null } }),
    prisma.episode.count(),
    prisma.episode.count({ where: { videoUrl: { not: null }, streamExpiresAt: { gt: now } } }),
    prisma.episode.count({ where: { videoUrl: { not: null }, streamExpiresAt: { lt: now } } }),
    prisma.episode.count({ where: { videoUrl: null } })
  ]).catch(() => Array(8).fill(-1));

  return res.json({
    ok: true,
    queue,
    worker,
    movies: {
      total: totalMovies,
      withStream: moviesWithStream,
      expired: moviesExpired,
      noStream: moviesNoStream
    },
    episodes: {
      total: totalEpisodes,
      withStream: episodesWithStream,
      expired: episodesExpired,
      noStream: episodesNoStream
    }
  });
}

// ─── FORCE REFRESH: POST /api/stream/force-refresh ───────────────────────────
// Fuerza el re-scraping de un contenido específico (uso admin/debug)
async function forceRefresh(req, res) {
  const tmdbId  = String(req.body?.tmdbId || req.query?.tmdbId || '');
  const type    = String(req.body?.type   || req.query?.type   || 'movie').toLowerCase();
  const season  = Number(req.body?.season  || req.query?.season  || 1);
  const episode = Number(req.body?.episode || req.query?.episode || 1);

  if (!tmdbId) {
    return res.status(400).json({ success: false, error: 'tmdbId requerido' });
  }

  console.log(`[stream] 🔧 Force-refresh solicitado: ${type}/${tmdbId}${type === 'tv' ? ` S${season}E${episode}` : ''}`);

  try {
    const scraped = await enqueue(tmdbId, type, season, episode, true); // force=true
    return res.json({
      success: true,
      url: scraped.url,
      source: scraped.source,
      streamType: scraped.streamType,
      allCandidates: scraped.allCandidates,
      duration: scraped.duration
    });
  } catch (error) {
    return res.status(503).json({ success: false, error: error.message });
  }
}

// ─── TRIGGER WORKER CYCLE: POST /api/stream/worker/run ───────────────────────
async function runWorkerCycle(req, res) {
  const result = await triggerManualCycle();
  return res.json({ success: true, ...result });
}

module.exports = {
  getStreamLink,
  registerStream,
  getMasterPlaylist,
  getSource,
  getResource,
  getStatus,
  forceRefresh,
  runWorkerCycle
};
