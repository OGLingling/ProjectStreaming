const axios = require('axios');

// ---------------- CACHE LRU ----------------
const CACHE_MAX_SIZE = 200;
const cache = new Map();

function cacheSet(key, value) {
  if (cache.has(key)) cache.delete(key);
  cache.set(key, value);
  if (cache.size > CACHE_MAX_SIZE) {
    const oldestKey = cache.keys().next().value;
    cache.delete(oldestKey);
  }
}

function cacheGet(key) {
  if (!cache.has(key)) return null;
  const value = cache.get(key);
  cache.delete(key);
  cache.set(key, value);
  return value;
}

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

  static buildCandidates(n) {
    const { tmdbId, isTV, season, episode } = n;
    const path = isTV ? `tv/${tmdbId}/${season}/${episode}` : `movie/${tmdbId}`;

    const candidates = [
      `https://vidsrc.me/embed/${path}`,
      `https://vidsrc.to/embed/${path}`,
      `https://vidsrc.xyz/embed/${path}`,
      `https://vidsrc.win/embed/${path}`,
      `https://player.vidsrc.co/embed/${path}`,
    ];

    if (isTV) {
      candidates.push(`https://www.2embed.cc/embedtv/${tmdbId}&s=${season}&e=${episode}`);
    } else {
      candidates.push(`https://www.2embed.cc/embed/${tmdbId}`);
    }
    return candidates;
  }

  static async isAlive(url) {
    const userAgents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0'
    ];

    const randomAgent = userAgents[Math.floor(Math.random() * userAgents.length)];

    try {
      const res = await axios.get(url, {
        timeout: 8000,
        headers: {
          'User-Agent': randomAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
          'Referer': new URL(url).origin,
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache'
        },
        validateStatus: () => true,
        maxRedirects: 5,
      });

      if (res.status !== 200) return false;

      const html = String(res.data || '');
      if (html.length < 800) return false;

      const videoSignals = [/player/i, /video/i, /source\s+src/i, /\.m3u8/i, /\.mp4/i, /iframe/i];
      const blockSignals = [/access denied/i, /403 forbidden/i, /cloudflare/i, /captcha/i];

      const hasVideoSignal = videoSignals.some((p) => p.test(html));
      const isBlocked = blockSignals.some((p) => p.test(html));

      return hasVideoSignal && !isBlocked;

    } catch {
      return false;
    }
  }

  static updateScore(url, ok) {
    try {
      const domain = new URL(url).hostname;
      if (!providerStats[domain]) providerStats[domain] = { ok: 0, fail: 0 };
      ok ? providerStats[domain].ok++ : providerStats[domain].fail++;
    } catch (e) {
      console.error("[ranking] Error actualizando score:", e.message);
    }
  }

  static sortProviders(list) {
    if (!Array.isArray(list) || list.length === 0) return [];
    return list.sort((a, b) => {
      const da = providerStats[new URL(a).hostname] || { ok: 0, fail: 0 };
      const db = providerStats[new URL(b).hostname] || { ok: 0, fail: 0 };
      return (db.ok - db.fail) - (da.ok - da.fail);
    });
  }

  static async getWorkingProviders(candidates) {
    if (!Array.isArray(candidates) || candidates.length === 0) return [];

    const checks = candidates.map((url) =>
      this.isAlive(url).then((ok) => {
        this.updateScore(url, ok);
        console.log(`[check] ${url} → ${ok}`);
        return { url, ok };
      }).catch(() => ({ url, ok: false }))
    );

    const results = await Promise.allSettled(checks);

    const working = results
      .filter((r) => r.status === 'fulfilled' && r.value && r.value.ok)
      .map((r) => r.value.url);

    // Protección contra 'reading map' y lista vacía
    if (working.length === 0) return [];

    return this.sortProviders(working);
  }

  static async createPayload(source) {
    const n = this.normalizeRequest(source);
    if (n.scenario === 'invalid') {
      return { success: false, candidates: [], debug_info: { reason: 'invalid_params' } };
    }

    const cacheKey = `${n.type}-${n.tmdbId}-${n.season}-${n.episode}`;
    const cached = cacheGet(cacheKey);
    if (cached) return cached;

    const candidates = n.searchMode ? this.buildCandidates(n) : [n.url];
    const working = await this.getWorkingProviders(candidates);

    const payload = {
      success: working.length > 0,
      candidates: working,
      tmdbId: n.tmdbId,
      type: n.type,
      searchMode: n.searchMode,
      ...(working.length === 0 && {
        debug_info: {
          reason: 'no_working_providers',
          detail: 'Todos fallaron el check',
          checked_count: candidates.length
        }
      })
    };

    if (payload.success) cacheSet(cacheKey, payload);
    return payload;
  }

  static async extractStreamUrl(source) {
    return await this.createPayload(source);
  }
}

module.exports = VideoScraper;