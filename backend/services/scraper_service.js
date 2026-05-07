const axios = require('axios');

// ---------------- CACHE LRU ----------------
const cache = new Map();
const CACHE_MAX_SIZE = 200;

function cacheGet(key) {
  if (!cache.has(key)) return null;
  const val = cache.get(key);
  cache.delete(key);
  cache.set(key, val);
  return val;
}

function cacheSet(key, val) {
  if (cache.has(key)) cache.delete(key);
  cache.set(key, val);
  if (cache.size > CACHE_MAX_SIZE) cache.delete(cache.keys().next().value);
}

// ---------------- LIMPIEZA DE DATOS ----------------
const sanitize = (v) => {
  if (v === undefined || v === null) return undefined;
  const s = String(v).trim();
  const invalid = ['null', 'undefined', 'none', 'nan', ''];
  return invalid.includes(s.toLowerCase()) ? undefined : s;
};

class VideoScraper {

  static buildCandidates(data) {
    const { tmdbId, type, season, episode } = data;
    const isTV = type === 'tv';

    // Forzamos valores por defecto si son undefined para evitar URLs rotas
    const s = season || 1;
    const e = episode || 1;

    const path = isTV ? `tv/${tmdbId}/${s}/${e}` : `movie/${tmdbId}`;

    // Lista maestra de providers confiables
    const base = [
      `https://vidsrc.me/embed/${path}`,
      `https://vidsrc.to/embed/${path}`,
      `https://vidsrc.xyz/embed/${path}`,
      `https://vidsrc.win/embed/${path}`,
      `https://player.vidsrc.co/embed/${path}`
    ];

    if (isTV) {
      base.push(`https://www.2embed.cc/embedtv/${tmdbId}&s=${s}&e=${e}`);
    } else {
      base.push(`https://www.2embed.cc/embed/${tmdbId}`);
    }

    return base;
  }

  static async createPayload(source) {
    // 1. Extracción y Sanitización estricta
    const tmdbId = sanitize(source.tmdbId) || sanitize(source.id);
    const type = String(source.type || '').toLowerCase().includes('tv') ? 'tv' : 'movie';
    const season = parseInt(source.season) || 1;
    const episode = parseInt(source.episode) || 1;

    // 2. Validación de seguridad
    if (!tmdbId || !/^\d+$/.test(tmdbId)) {
      return {
        success: false,
        reason: 'invalid_tmdb_id',
        message: 'ID de TMDB no válido o ausente'
      };
    }

    // 3. Cache Check
    const cacheKey = `c_${type}_${tmdbId}_${season}_${episode}`;
    const cached = cacheGet(cacheKey);
    if (cached) return cached;

    // 4. Generación de Candidatos (Sin Health Check en servidor para evitar bloqueos)
    const candidates = this.buildCandidates({ tmdbId, type, season, episode });

    const payload = {
      success: candidates.length > 0,
      tmdbId,
      type,
      results: candidates.map(url => ({
        url,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Referer': new URL(url).origin
        }
      })),
      timestamp: new Date().toISOString()
    };

    if (payload.success) cacheSet(cacheKey, payload);

    return payload;
  }

  static async extractStreamUrl(source) {
    return await this.createPayload(source);
  }
}

module.exports = VideoScraper;