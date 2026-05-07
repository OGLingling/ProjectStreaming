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
  static buildCandidates({ tmdbId, type, season, episode }) {
    const isTV = type === 'tv';
    const s = season || 1;
    const e = episode || 1;

    // Construcción de rutas según el estándar de los providers
    const path = isTV ? `tv/${tmdbId}/${s}/${e}` : `movie/${tmdbId}`;

    const urls = [
      `https://vidsrc.me/embed/${path}`,
      `https://vidsrc.to/embed/${path}`,
      `https://vidsrc.xyz/embed/${path}`,
      `https://vidsrc.win/embed/${path}`,
      `https://player.vidsrc.co/embed/${path}`
    ];

    if (isTV) {
      urls.push(`https://www.2embed.cc/embedtv/${tmdbId}&s=${s}&e=${e}`);
    } else {
      urls.push(`https://www.2embed.cc/embed/${tmdbId}`);
    }

    return urls.map(url => ({
      url,
      headers: { 'Referer': new URL(url).origin }
    }));
  }

  static async extractStreamUrl(data) {
    // Si llegamos aquí es porque el controlador ya validó el tmdbId
    const results = this.buildCandidates({
      tmdbId: data.tmdbId,
      type: data.type,
      season: data.season,
      episode: data.episode
    });

    return {
      success: true, // Siempre true si hay candidatos construidos
      tmdbId: data.tmdbId,
      type: data.type,
      results: results
    };
  }
}

module.exports = VideoScraper;