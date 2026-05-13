const axios = require('axios');
const {
  createStreamSession,
  getStreamSession
} = require('../services/stream_session_store');

const MOBILE_USER_AGENT =
  'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

const isHttpUrl = (value) => /^https?:\/\//i.test(String(value || ''));

const encodeUrl = (url) => Buffer.from(url, 'utf8').toString('base64url');
const decodeUrl = (value) => Buffer.from(value, 'base64url').toString('utf8');

function buildHeaders(targetUrl, sourceUrl, customHeaders = {}) {
  const targetOrigin = new URL(targetUrl).origin;
  const sourceOrigin = sourceUrl && isHttpUrl(sourceUrl)
    ? new URL(sourceUrl).origin
    : targetOrigin;

  return {
    'User-Agent': customHeaders['User-Agent'] || customHeaders['user-agent'] || MOBILE_USER_AGENT,
    'Referer': customHeaders.Referer || customHeaders.referer || `${sourceOrigin}/`,
    'Origin': customHeaders.Origin || customHeaders.origin || sourceOrigin,
    'Accept': customHeaders.Accept || customHeaders.accept || '*/*',
    'Accept-Language': customHeaders['Accept-Language'] || 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7'
  };
}

function absoluteUrl(baseUrl, maybeRelativeUrl) {
  if (!maybeRelativeUrl || maybeRelativeUrl.startsWith('#')) return maybeRelativeUrl;
  return new URL(maybeRelativeUrl, baseUrl).toString();
}

function rewriteAttributeUris(line, baseUrl, sessionId, req) {
  return line.replace(/URI="([^"]+)"/g, (_, value) => {
    if (value.startsWith('data:') || value.startsWith('skd:')) {
      return `URI="${value}"`;
    }

    const absolute = absoluteUrl(baseUrl, value);
    const proxyUrl = `${req.protocol}://${req.get('host')}/api/stream/${sessionId}/resource?u=${encodeUrl(absolute)}`;
    return `URI="${proxyUrl}"`;
  });
}

function rewritePlaylist(body, baseUrl, sessionId, req) {
  return body
    .split(/\r?\n/)
    .map((rawLine) => {
      const line = rawLine.trim();
      if (!line) return rawLine;

      if (line.startsWith('#')) {
        return rewriteAttributeUris(rawLine, baseUrl, sessionId, req);
      }

      const absolute = absoluteUrl(baseUrl, line);
      return `${req.protocol}://${req.get('host')}/api/stream/${sessionId}/resource?u=${encodeUrl(absolute)}`;
    })
    .join('\n');
}

async function fetchUpstream(url, session, responseType = 'stream') {
  return axios.get(url, {
    responseType,
    timeout: 20000,
    maxRedirects: 5,
    headers: buildHeaders(url, session.sourceUrl, session.headers),
    validateStatus: (status) => status >= 200 && status < 500
  });
}

async function registerStream(req, res) {
  const targetUrl = req.body?.url || req.query?.url;
  const sourceUrl = req.body?.sourceUrl || req.body?.referer || req.query?.sourceUrl || null;

  if (!isHttpUrl(targetUrl)) {
    return res.status(400).json({ success: false, error: 'URL de stream invalida' });
  }

  const headers = buildHeaders(targetUrl, sourceUrl, req.body?.headers || {});
  const session = createStreamSession({ targetUrl, sourceUrl, headers });
  const isHls = targetUrl.toLowerCase().includes('.m3u8');
  const streamPath = isHls ? 'master.m3u8' : 'source';

  return res.json({
    success: true,
    streamId: session.id,
    streamUrl: `${req.protocol}://${req.get('host')}/api/stream/${session.id}/${streamPath}`,
    expiresAt: new Date(session.expiresAt).toISOString()
  });
}

async function getMasterPlaylist(req, res) {
  const session = getStreamSession(req.params.streamId);
  if (!session) {
    return res.status(404).send('Stream session expired');
  }

  return serveResource(req, res, session.targetUrl, session);
}

async function getSource(req, res) {
  const session = getStreamSession(req.params.streamId);
  if (!session) {
    return res.status(404).send('Stream session expired');
  }

  return serveResource(req, res, session.targetUrl, session);
}

async function getResource(req, res) {
  const session = getStreamSession(req.params.streamId);
  if (!session) {
    return res.status(404).send('Stream session expired');
  }

  let targetUrl;
  try {
    targetUrl = decodeUrl(req.query.u);
  } catch (error) {
    return res.status(400).send('Invalid resource URL');
  }

  if (!isHttpUrl(targetUrl)) {
    return res.status(400).send('Invalid resource URL');
  }

  return serveResource(req, res, targetUrl, session);
}

async function serveResource(req, res, targetUrl, session) {
  try {
    const upstream = await fetchUpstream(targetUrl, session, 'arraybuffer');
    const contentType = String(upstream.headers['content-type'] || '').toLowerCase();
    const looksLikePlaylist = targetUrl.toLowerCase().includes('.m3u8') ||
      contentType.includes('mpegurl') ||
      contentType.includes('application/vnd.apple.mpegurl');

    res.set('Access-Control-Allow-Origin', '*');
    res.set('Cache-Control', 'no-store');

    if (upstream.status >= 400) {
      return res.status(upstream.status).send(upstream.data);
    }

    if (looksLikePlaylist) {
      const playlist = Buffer.from(upstream.data).toString('utf8');
      const rewritten = rewritePlaylist(playlist, targetUrl, session.id, req);
      res.set('Content-Type', 'application/vnd.apple.mpegurl');
      return res.send(rewritten);
    }

    if (contentType) {
      res.set('Content-Type', contentType);
    }

    return res.send(Buffer.from(upstream.data));
  } catch (error) {
    console.error('[stream] Proxy error:', error.message);
    return res.status(502).send('No se pudo obtener el recurso de video');
  }
}

module.exports = {
  registerStream,
  getMasterPlaylist,
  getSource,
  getResource
};
