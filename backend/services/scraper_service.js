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

    return [
      `https://vidsrc.me/embed/${path}`,
      `https://vidsrc.to/embed/${path}`,
      `https://vidsrc.xyz/embed/${path}`,
      `https://vidsrc.win/embed/${path}`,
      `https://player.vidsrc.co/embed/${path}`,
      isTV ? `https://www.2embed.cc/embedtv/${tmdbId}&s=${s}&e=${e}` : `https://www.2embed.cc/embed/${tmdbId}`
    ].map(url => ({
      url,
      headers: { 'Referer': new URL(url).origin, 'User-Agent': 'Mozilla/5.0...' }
    }));
  }

  static async extractStreamUrl(data) {
    const tmdbId = data.tmdbId || data.id;
    if (!tmdbId) throw new Error('MISSING_ID');

    const type = String(data.type || '').toLowerCase().includes('tv') ? 'tv' : 'movie';
    const results = this.buildCandidates({
      tmdbId,
      type,
      season: parseInt(data.season),
      episode: parseInt(data.episode)
    });

    return {
      success: true,
      tmdbId,
      type,
      results
    };
  }
}

module.exports = VideoScraper;