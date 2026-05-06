const { PrismaClient } = require('@prisma/client');
const axios = require('axios');

const prisma = new PrismaClient();

// ---------------- CACHE Y STATS ----------------
const cache = new Map();
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
    return raw.includes('tv') ? 'tv' : 'movie';
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

    return [
      `https://vidsrc.me/embed/${path}`,
      `https://vidsrc.to/embed/${path}`,
      `https://vidsrc.xyz/embed/${path}`,
      `https://vidsrc.win/embed/${path}`,
      `https://player.vidsrc.co/embed/${path}`,
      `https://www.2embed.cc/embed/${tmdbId}`
    ];
  }

  // ---------------- HEALTH CHECK ----------------
  static async isAlive(url) {
    try {
      const res = await axios.get(url, {
        timeout: 4000,
        headers: { 'User-Agent': 'Mozilla/5.0' },
        validateStatus: () => true
      });

      if (res.status !== 200) return false;

      const html = res.data || '';

      return html.includes('iframe') || html.length > 1000;

    } catch {
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
      const da = providerStats[new URL(a).hostname] || {};
      const db = providerStats[new URL(b).hostname] || {};

      const sa = (da.ok || 0) - (da.fail || 0);
      const sb = (db.ok || 0) - (db.fail || 0);

      return sb - sa;
    });
  }

  // ---------------- CORE ----------------
  static async getWorkingProviders(candidates) {

    const results = [];

    for (const url of candidates) {
      const ok = await this.isAlive(url);

      this.updateScore(url, ok);

      console.log(`[check] ${url} → ${ok}`);

      if (ok) results.push(url);
    }

    return this.sortProviders(results);
  }

  // ---------------- MAIN ----------------
  static async createPayload(source) {

    const normalized = this.normalizeRequest(source);

    if (normalized.scenario === 'invalid') {
      return { success: false, candidates: [] };
    }

    const cacheKey = `${normalized.tmdbId}-${normalized.season}-${normalized.episode}`;

    if (cache.has(cacheKey)) {
      console.log('[cache] HIT');
      return cache.get(cacheKey);
    }

    let candidates = [];

    if (normalized.searchMode) {
      candidates = this.buildCandidates(normalized);
    } else {
      candidates = [normalized.url];
    }

    const working = await this.getWorkingProviders(candidates);

    const payload = {
      success: working.length > 0,
      candidates: working,
      tmdbId: normalized.tmdbId,
      searchMode: normalized.searchMode
    };

    cache.set(cacheKey, payload);

    if (cache.size > 200) cache.clear();

    return payload;
  }

  static async extractStreamUrl(source) {
    return await this.createPayload(source);
  }
}

module.exports = VideoScraper;