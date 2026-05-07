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
    const path = isTV ? `tv/${tmdbId}/${s}/${e}` : `movie/${tmdbId}`;

    // Lista de espejos (mirrors)
    const urls = [
      `https://vidsrc.me/embed/${path}`,
      `https://vidsrc.to/embed/${path}`,
      `https://vidsrc.xyz/embed/${path}`,
      `https://vidsrc.win/embed/${path}`,
      `https://player.vidsrc.co/embed/${path}`,
      isTV ? `https://www.2embed.cc/embedtv/${tmdbId}&s=${s}&e=${e}` : `https://www.2embed.cc/embed/${tmdbId}`
    ];

    return urls.map(url => ({ url, origin: new URL(url).origin }));
  }

  static async extractStreamUrl(data) {
    console.log('[service] Generando candidatos para:', data.tmdbId);
    const results = this.buildCandidates(data);
    return { success: true, results };
  }
}

module.exports = VideoScraper;