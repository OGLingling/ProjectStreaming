const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

// ---------------------------------------------------------------------------
// Utilidades de sanitización
// ---------------------------------------------------------------------------

const INVALID_STRINGS = new Set(['null', 'undefined', 'none', 'nan', '']);

const sanitize = (v) => {
  if (v === undefined || v === null) return undefined;
  const s = String(v).trim();
  return INVALID_STRINGS.has(s.toLowerCase()) ? undefined : s;
};

const isValidUrl = (s) => /^https?:\/\//i.test(String(s || ''));
const isNumericId = (s) => /^\d{1,20}$/.test(String(s || ''));

// ---------------------------------------------------------------------------
// VideoScraper
// ---------------------------------------------------------------------------

class VideoScraper {

  static normalizeMediaType(value) {
    const raw = String(value || '').toLowerCase().trim();
    return raw.includes('serie') || raw.includes('tv') ? 'tv' : 'movie';
  }

  static normalizePositiveInt(value, fallback = undefined) {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
  }

  // 🔥 NUEVA NORMALIZACIÓN ROBUSTA
  static normalizeRequest(source) {
    const raw = source && typeof source === 'object' ? source : {};

    const url = sanitize(raw.url);
    const tmdbId = sanitize(raw.tmdbId) ?? sanitize(raw.id);
    const type = this.normalizeMediaType(raw.type);

    const isTV = type === 'tv';

    const season = this.normalizePositiveInt(raw.season);
    const episode = this.normalizePositiveInt(raw.episode);

    const hasValidUrl = url && isValidUrl(url);
    const hasValidTmdb = tmdbId && isNumericId(tmdbId);

    // 🎯 Escenario A: URL directa
    if (hasValidUrl) {
      return {
        scenario: 'url',
        searchMode: false,
        url,
        tmdbId,
        type,
        isTV,
        season,
        episode
      };
    }

    // 🎯 Escenario B: búsqueda por ID
    if (hasValidTmdb) {
      return {
        scenario: 'tmdb',
        searchMode: true,
        url: undefined,
        tmdbId,
        type,
        isTV,
        season,
        episode
      };
    }

    // 🎯 Escenario inválido
    return {
      scenario: 'invalid',
      searchMode: false,
      url: undefined,
      tmdbId,
      type,
      isTV,
      season,
      episode
    };
  }

  static validateNormalized({ scenario, tmdbId, isTV, season, episode }) {

    if (scenario === 'url') return { valid: true };

    if (scenario === 'invalid') {
      return {
        valid: false,
        reason: 'missing_identifiers',
        detail: 'No se proporcionó URL válida ni tmdbId válido.',
        hint: 'Envía una URL de embed o un tmdbId numérico.'
      };
    }

    if (!isNumericId(tmdbId)) {
      return {
        valid: false,
        reason: 'invalid_tmdb_id_format',
        detail: `tmdbId="${tmdbId}" no es válido.`,
        hint: 'Debe ser un número (ej: 550, 1396)'
      };
    }

    if (isTV && !season) {
      return {
        valid: false,
        reason: 'missing_season',
        detail: 'TV requiere season ≥ 1'
      };
    }

    if (isTV && !episode) {
      return {
        valid: false,
        reason: 'missing_episode',
        detail: 'TV requiere episode ≥ 1'
      };
    }

    return { valid: true };
  }

  static buildCandidates(normalized) {
    const { scenario, url, tmdbId, isTV, season = 1, episode = 1 } = normalized;

    if (scenario === 'url') return [url];

    if (!tmdbId) return [];

    const s = season ?? 1;
    const e = episode ?? 1;

    const pathSegment = isTV ? `tv/${tmdbId}/${s}/${e}` : `movie/${tmdbId}`;

    return [
      `https://vidsrc.me/embed/${pathSegment}`,
      `https://vidsrc.to/embed/${pathSegment}`,
      `https://vidsrc.xyz/embed/${pathSegment}`,
      `https://vidsrc.win/embed/${pathSegment}`,
      `https://vidsrc.wiki/embed/${pathSegment}`,
      `https://player.vidsrc.co/embed/${pathSegment}`,
      `https://embed.smashystream.com/playere.php?tmdb=${tmdbId}`,
      `https://www.2embed.cc/embed/${tmdbId}`
    ];
  }

  static searchByTmdbId(normalized) {
    console.log(`[scraper] 🔍 searchMode ACTIVADO → tmdbId=${normalized.tmdbId}`);
    return this.buildCandidates(normalized);
  }

  static createPayload(source) {
    const normalized = this.normalizeRequest(source);
    const validation = this.validateNormalized(normalized);

    if (!validation.valid) {
      return {
        success: false,
        candidates: [],
        debug_info: { status: 'error', ...validation }
      };
    }

    let candidates = [];

    if (normalized.searchMode) {
      candidates = this.searchByTmdbId(normalized);
    } else {
      candidates = [normalized.url];
    }

    return {
      success: candidates.length > 0,
      searchMode: normalized.searchMode,
      tmdbId: normalized.tmdbId ?? null,
      type: normalized.type,
      season: normalized.season ?? null,
      episode: normalized.episode ?? null,
      candidates,
      debug_info: {
        status: 'ok',
        searchMode: normalized.searchMode,
        candidateCount: candidates.length
      }
    };
  }

  static async extractStreamUrl(source) {
    try {
      return this.createPayload(source);
    } catch (e) {
      return {
        success: false,
        candidates: [],
        debug_info: {
          status: 'error',
          reason: 'internal_exception',
          detail: e.message
        }
      };
    }
  }

  static async saveLog() { } // opcional mantener igual
}

module.exports = VideoScraper;