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

  /**
   * Genera la lista de candidatos. 
   * Nota: Se eliminó el health check interno para evitar el baneo de IP en Render.
   */
  static buildCandidates(n) {
    const { tmdbId, isTV, season, episode } = n;
    const path = isTV ? `tv/${tmdbId}/${season}/${episode}` : `movie/${tmdbId}`;

    return [
      `https://vidsrc.me/embed/${path}`,
      `https://vidsrc.to/embed/${path}`,
      `https://vidsrc.xyz/embed/${path}`,
      `https://vidsrc.win/embed/${path}`,
      `https://player.vidsrc.co/embed/${path}`,
      isTV
        ? `https://www.2embed.cc/embedtv/${tmdbId}&s=${season}&e=${episode}`
        : `https://www.2embed.cc/embed/${tmdbId}`
    ];
  }

  /**
   * Proporciona los headers necesarios para que la App Flutter 
   * realice el bypass de seguridad de los providers.
   */
  static getClientHeaders(url) {
    return {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Referer': new URL(url).origin,
      'Origin': new URL(url).origin
    };
  }

  static async createPayload(source) {
    const normalized = this.normalizeRequest(source);

    if (normalized.scenario === 'invalid') {
      return {
        success: false,
        error: 'INVALID_PARAMS',
        message: 'No se pudo resolver un tmdbId o URL válidos'
      };
    }

    const cacheKey = `${normalized.type}-${normalized.tmdbId}-${normalized.season}-${normalized.episode}`;
    const cached = cacheGet(cacheKey);
    if (cached) return cached;

    // Obtenemos los candidatos potenciales
    const candidates = normalized.searchMode
      ? this.buildCandidates(normalized)
      : [normalized.url];

    /**
     * ESTRATEGIA HÍBRIDA:
     * El servidor no valida (para evitar 403 de Render).
     * Retorna todos los candidatos con sus headers sugeridos.
     * La App Flutter deberá intentar cargarlos.
     */
    const payload = {
      success: true,
      tmdbId: normalized.tmdbId,
      type: normalized.type,
      searchMode: normalized.searchMode,
      results: candidates.map(url => ({
        url,
        headers: this.getClientHeaders(url)
      })),
      client_side_validation_required: true
    };

    cacheSet(cacheKey, payload);
    return payload;
  }

  static async extractStreamUrl(source) {
    return await this.createPayload(source);
  }
}

module.exports = VideoScraper;