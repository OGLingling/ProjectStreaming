const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ---------------------------------------------------------------------------
// Utilidades de sanitización
// ---------------------------------------------------------------------------

/** Strings que nunca son valores reales (Dart null.toString(), etc.) */
const INVALID_STRINGS = new Set(['null', 'undefined', 'none', 'nan', '']);

const sanitize = (v) => {
  if (v === undefined || v === null) return undefined;
  const s = String(v).trim();
  return INVALID_STRINGS.has(s.toLowerCase()) ? undefined : s;
};

const isValidUrl  = (s) => /^https?:\/\//i.test(String(s || ''));
const isNumericId = (s) => /^\d{1,20}$/.test(String(s || ''));

// ---------------------------------------------------------------------------
// VideoScraper
// ---------------------------------------------------------------------------

class VideoScraper {
  // -------------------------------------------------------------------------
  // Helpers de normalización primitivos
  // -------------------------------------------------------------------------

  static normalizeMediaType(value) {
    const raw = String(value || '').toLowerCase().trim();
    return raw.includes('serie') || raw.includes('tv') ? 'tv' : 'movie';
  }

  static normalizePositiveInt(value, fallback = undefined) {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
  }

  // -------------------------------------------------------------------------
  // normalizeRequest — detecta el escenario y produce un objeto canónico
  //
  // Escenarios:
  //   A) 'url'   — Se recibió una URL directa de embed válida (https://...)
  //   B) 'tmdb'  — Se recibió tmdbId numérico (movie o tv)
  // -------------------------------------------------------------------------

  static normalizeRequest(source) {
    const raw = source && typeof source === 'object' ? source : {};

    const url    = sanitize(raw.url);
    const tmdbId = sanitize(raw.tmdbId) ?? sanitize(raw.id);
    const type   = this.normalizeMediaType(raw.type);
    const isTV   = type === 'tv';
    const season  = this.normalizePositiveInt(raw.season);
    const episode = this.normalizePositiveInt(raw.episode);

    // Escenario A: URL directa de embed
    if (url && isValidUrl(url)) {
      return { scenario: 'url', url, tmdbId, type, isTV, season, episode };
    }

    // Escenario B/C: por tmdbId (movie o tv)
    return { scenario: 'tmdb', url: undefined, tmdbId, type, isTV, season, episode };
  }

  // -------------------------------------------------------------------------
  // validateNormalized — retorna { valid, reason, detail, hint }
  // -------------------------------------------------------------------------

  static validateNormalized({ scenario, tmdbId, isTV, season, episode }) {
    if (scenario === 'url') return { valid: true };

    if (!tmdbId) {
      return {
        valid:  false,
        reason: 'missing_tmdb_id',
        detail: 'No se recibió un tmdbId válido ni una URL directa de embed.',
        hint:   'Verifica que el campo tmdb_id en tu DB no sea NULL y sea un ID numérico de TMDB.'
      };
    }

    if (!isNumericId(tmdbId)) {
      return {
        valid:  false,
        reason: 'invalid_tmdb_id_format',
        detail: `tmdbId="${tmdbId}" no es un entero positivo.`,
        hint:   'Usa el ID numérico de TMDB (ej: 550, 1396). Los IDs de IMDB (tt...) no son válidos aquí.'
      };
    }

    if (isTV && !season) {
      return {
        valid:  false,
        reason: 'missing_season',
        detail: 'type=tv requiere season ≥ 1.',
        hint:   'Asegúrate de enviar el parámetro season cuando el tipo es tv o serie.'
      };
    }

    if (isTV && !episode) {
      return {
        valid:  false,
        reason: 'missing_episode',
        detail: 'type=tv requiere episode ≥ 1.',
        hint:   'Asegúrate de enviar el parámetro episode cuando el tipo es tv o serie.'
      };
    }

    return { valid: true };
  }

  // -------------------------------------------------------------------------
  // buildCandidates — construye la lista de URLs de providers conocidos
  //
  // Prioridad:
  //   1. vidsrc.me  (más estable históricamente)
  //   2. vidsrc.to  (segunda opción)
  //   3. variantes adicionales de vidsrc
  //   4. SmashyStream
  //   5. 2embed
  //   6. multiembed (fallback genérico)
  // -------------------------------------------------------------------------

  static buildCandidates(normalized) {
    const { scenario, url, tmdbId, isTV, season = 1, episode = 1 } = normalized;

    // Escenario A: URL directa → candidato único
    if (scenario === 'url') return [url];

    if (!tmdbId) return [];

    const s = season  ?? 1;
    const e = episode ?? 1;

    // Fragmentos reutilizables de path / query
    const pathSegment  = isTV ? `tv/${tmdbId}/${s}/${e}`        : `movie/${tmdbId}`;
    const queryVariant = isTV ? `tv?tmdb=${tmdbId}&season=${s}&episode=${e}` : `movie?tmdb=${tmdbId}`;
    const smashyPath   = isTV ? `playere.php?tmdb=${tmdbId}&season=${s}&episode=${e}` : `playere.php?tmdb=${tmdbId}`;
    const twoEmbedPath = isTV ? `embedtv/${tmdbId}&s=${s}&e=${e}` : `embed/${tmdbId}`;
    const multiEmbed   = `https://multiembed.mov/directstream.php?video_id=${tmdbId}&tmdb=1` +
                         (isTV ? `&s=${s}&e=${e}` : '');

    return [
      // --- vidsrc path-based (mayor prioridad) ---
      `https://vidsrc.me/embed/${pathSegment}`,
      `https://vidsrc.to/embed/${pathSegment}`,
      `https://vidsrc.xyz/embed/${pathSegment}`,
      `https://vidsrc.win/embed/${pathSegment}`,
      `https://vidsrc.wiki/embed/${pathSegment}`,
      `https://player.vidsrc.co/embed/${pathSegment}`,
      // --- vidsrc query-param variants ---
      `https://vidsrc.me/embed/${queryVariant}`,
      `https://vidsrc.to/embed/${queryVariant}`,
      `https://vidsrc.win/embed/${queryVariant}`,
      // --- otros providers ---
      `https://embed.smashystream.com/${smashyPath}`,
      `https://www.2embed.cc/${twoEmbedPath}`,
      // --- fallback genérico ---
      multiEmbed
    ];
  }

  // -------------------------------------------------------------------------
  // createPayload — punto de entrada principal
  // -------------------------------------------------------------------------

  static createPayload(source) {
    const normalized = this.normalizeRequest(source);
    const validation = this.validateNormalized(normalized);

    if (!validation.valid) {
      return {
        success:    false,
        candidates: [],
        debug_info: { status: 'error', ...validation }
      };
    }

    const candidates = this.buildCandidates(normalized);

    return {
      success:      candidates.length > 0,
      tmdbId:       normalized.tmdbId  ?? null,
      source:       normalized.url     ?? normalized.tmdbId ?? '',
      type:         normalized.type,
      season:       normalized.season  ?? null,
      episode:      normalized.episode ?? null,
      scenario:     normalized.scenario,
      providerMode: 'client-side-resolution',
      candidates,
      debug_info: candidates.length > 0
        ? { status: 'ok', candidateCount: candidates.length, scenario: normalized.scenario }
        : {
            status:  'error',
            reason:  'empty_candidates',
            detail:  'Los proveedores no generaron candidatos para este input.',
            scenario: normalized.scenario
          }
    };
  }

  // -------------------------------------------------------------------------
  // extractStreamUrl — wrapper async con logging
  // -------------------------------------------------------------------------

  static async extractStreamUrl(source) {
    const start = Date.now();
    let payload = null;
    let err     = null;

    try {
      payload = this.createPayload(source);
      return payload;
    } catch (e) {
      err = e.message;
      console.error('[scraper_service] Error inesperado:', e.message);
      return {
        success:      false,
        candidates:   [],
        debug_info: { status: 'error', reason: 'internal_exception', detail: e.message }
      };
    } finally {
      const success = !!(payload?.candidates?.length);
      // Evita loggear URLs completas con tokens; solo identifica el recurso
      const logTarget = typeof source === 'object'
        ? JSON.stringify({ tmdbId: sanitize(source?.tmdbId), url: sanitize(source?.url) })
        : String(source || '');

      await this.saveLog(
        logTarget,
        success,
        payload ? JSON.stringify(payload.candidates) : null,
        err,
        Date.now() - start
      );
    }
  }

  // -------------------------------------------------------------------------
  // saveLog
  // -------------------------------------------------------------------------

  static async saveLog(targetUrl, success, result, error, duration) {
    try {
      await prisma.scrapeLog.create({
        data: { targetUrl, success, streamUrl: result, error, duration }
      });
    } catch (dbError) {
      console.error('[scraper_service] Error BD Log:', dbError.message);
    }
  }
}

module.exports = VideoScraper;
