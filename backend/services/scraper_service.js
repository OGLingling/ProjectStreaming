const axios = require('axios');

// ---------------- CACHE LRU ----------------
const CACHE_MAX_SIZE = 200;
const cache = new Map();

/**
 * LRU simple: cuando el Map supera el límite,
 * elimina la entrada más antigua (primera en inserción).
 */
function cacheSet(key, value) {
  if (cache.has(key)) cache.delete(key); // renueva posición
  cache.set(key, value);
  if (cache.size > CACHE_MAX_SIZE) {
    const oldestKey = cache.keys().next().value;
    cache.delete(oldestKey);
  }
}

function cacheGet(key) {
  if (!cache.has(key)) return null;
  // Renueva posición (LRU)
  const value = cache.get(key);
  cache.delete(key);
  cache.set(key, value);
  return value;
}

// ---------------- STATS (en memoria, best-effort) ----------------
// ⚠️ Se resetea en cada reinicio del servidor.
// Para persistencia real se necesita Redis o BD.
const providerStats = {};

// ---------------- UTILS ----------------
const INVALID_STRINGS = new Set(['null', 'undefined', 'none', 'nan', '']);

const sanitize = (v) => {
  if (v === undefined || v === null) return undefined;
  const s = String(v).trim();
  return INVALID_STRINGS.has(s.toLowerCase()) ? undefined : s;
};

const isValidUrl = (s) => /^https?:\/\//i.test(String(s || ''));
const isNumericId = (s) => /^\d+$/.test(String(s || ''));

// ---------------- CLASS ----------------
class VideoScraper {

  // ---------------- NORMALIZACIÓN ----------------
  static normalizeMediaType(value) {
    const raw = String(value || '').toLowerCase();
    return raw.includes('tv') || raw.includes('serie') ? 'tv' : 'movie';
  }

  static normalizeRequest(source) {
    const raw = source || {};

    const url = sanitize(raw.url);
    const tmdbId = sanitize(raw.tmdbId) ?? sanitize(raw.id);
    const type = this.normalizeMediaType(raw.type);

    const isTV = type === 'tv';
    const season = Number(raw.season) || 1;
    const episode = Number(raw.episode) || 1;

    if (url && isValidUrl(url)) {
      return { scenario: 'url', searchMode: false, url, tmdbId, type, isTV, season, episode };
    }

    if (tmdbId && isNumericId(tmdbId)) {
      return { scenario: 'tmdb', searchMode: true, url: null, tmdbId, type, isTV, season, episode };
    }

    return { scenario: 'invalid' };
  }

  // ---------------- PROVIDERS ----------------
  static buildCandidates(n) {
    const { tmdbId, isTV, season, episode } = n;

    const path = isTV
      ? `tv/${tmdbId}/${season}/${episode}`
      : `movie/${tmdbId}`;

    const candidates = [
      `https://vidsrc.me/embed/${path}`,
      `https://vidsrc.to/embed/${path}`,
      `https://vidsrc.xyz/embed/${path}`,
      `https://vidsrc.win/embed/${path}`,
      `https://player.vidsrc.co/embed/${path}`,
    ];

    // FIX: 2embed tiene ruta distinta para TV
    if (isTV) {
      candidates.push(
        `https://www.2embed.cc/embedtv/${tmdbId}&s=${season}&e=${episode}`
      );
    } else {
      candidates.push(
        `https://www.2embed.cc/embed/${tmdbId}`
      );
    }

    return candidates;
  }

  // ---------------- HEALTH CHECK MEJORADO ----------------
  static async isAlive(url) {
    const userAgents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Mobile/15E148 Safari/604.1'
    ];

    const randomAgent = userAgents[Math.floor(Math.random() * userAgents.length)];

    try {
      const res = await axios.get(url, {
        timeout: 8000, // Un poco más de margen para Render
        headers: {
          'User-Agent': randomAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'es-ES,es;q=0.8,en-US;q=0.5,en;q=0.3',
          'Referer': new URL(url).origin, // Engañamos al server: "Vengo de tu propia web"
          'Upgrade-Insecure-Requests': '1',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'cross-site',
        },
        validateStatus: () => true,
        maxRedirects: 5,
      });

      if (res.status !== 200) return false;

      const html = String(res.data || '');

      // Si el HTML es muy corto, probablemente es un desafío de Cloudflare o error
      if (html.length < 800) return false;

      const videoSignals = [
        /player/i, /video/i, /source\s+src/i, /\.m3u8/i, /\.mp4/i,
        /jwplayer/i, /plyr/i, /videojs/i, /iframe/i, /base64/i
      ];

      const blockSignals = [
        /access denied/i, /403 forbidden/i, /cloudflare/i,
        /just a moment/i, /captcha/i, /ddos/i, /robot/i
      ];

      const hasVideoSignal = videoSignals.some((p) => p.test(html));
      const isBlocked = blockSignals.some((p) => p.test(html));

      return hasVideoSignal && !isBlocked;

    } catch (err) {
      // Si hay error de conexión (EHOSTUNREACH), el provider nos tiene fichados
      return false;
    }
  }

  // ---------------- RANKING ----------------
  static updateScore(url, ok) {
    const domain = new URL(url).hostname;
    if (!providerStats[domain]) {
      providerStats[domain] = { ok: 0, fail: 0 };
    }
    ok ? providerStats[domain].ok++ : providerStats[domain].fail++;
  }

  static sortProviders(list) {
    return list.sort((a, b) => {
      const da = providerStats[new URL(a).hostname] || { ok: 0, fail: 0 };
      const db = providerStats[new URL(b).hostname] || { ok: 0, fail: 0 };
      const sa = da.ok - da.fail;
      const sb = db.ok - db.fail;
      return sb - sa;
    });
  }

  // ---------------- CORE — PARALELO ----------------
  static async getWorkingProviders(candidates) {

    // FIX: paralelo en lugar de secuencial (era hasta 24s de espera)
    const checks = candidates.map((url) =>
      this.isAlive(url)
        .then((ok) => {
          this.updateScore(url, ok);
          console.log(`[check] ${url} → ${ok}`);
          return { url, ok };
        })
        .catch((err) => {
          console.warn(`[check] ${url} → ERROR: ${err.message}`);
          this.updateScore(url, false);
          return { url, ok: false };
        })
    );

    const results = await Promise.allSettled(checks);

    const working = results
      .filter((r) => r.status === 'fulfilled' && r.value.ok)
      .map((r) => r.value.url);

    return this.sortProviders(working);
  }

  // ---------------- MAIN ----------------
  static async createPayload(source) {

    const normalized = this.normalizeRequest(source);

    if (normalized.scenario === 'invalid') {
      return {
        success: false,
        candidates: [],
        debug_info: {
          reason: 'invalid_params',
          detail: 'No se pudo resolver un tmdbId o URL válidos'
        }
      };
    }

    // FIX: cache key incluye tipo, season y episode
    const cacheKey = `${normalized.type}-${normalized.tmdbId}-${normalized.season}-${normalized.episode}`;

    const cached = cacheGet(cacheKey);
    if (cached) {
      console.log('[cache] HIT →', cacheKey);
      return cached;
    }

    const candidates = normalized.searchMode
      ? this.buildCandidates(normalized)
      : [normalized.url];

    const working = await this.getWorkingProviders(candidates);

    const payload = {
      success: working.length > 0,
      candidates: working,
      tmdbId: normalized.tmdbId,
      type: normalized.type,
      searchMode: normalized.searchMode,
      ...(working.length === 0 && {
        debug_info: {
          reason: 'no_working_providers',
          detail: 'Todos los providers fallaron el health check',
          checked: candidates.length
        }
      })
    };

    cacheSet(cacheKey, payload);

    return payload;
  }

  static async extractStreamUrl(source) {
    return await this.createPayload(source);
  }
}

module.exports = VideoScraper;