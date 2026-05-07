const VideoScraper = require('../services/scraper_service');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const describeParams = (params) =>
  Object.fromEntries(
    Object.entries(params || {}).map(([key, value]) => [
      key,
      { value, type: Array.isArray(value) ? 'array' : typeof value }
    ])
  );

const INVALID_STRINGS = new Set(['null', 'undefined', 'none', 'nan']);

const firstValue = (...values) => {
  const value = values.find((item) => {
    if (item === undefined || item === null) return false;
    const s = String(item).toLowerCase().trim();
    return s !== '' && !INVALID_STRINGS.has(s);
  });
  return Array.isArray(value) ? value[0] : value;
};

// ---------------------------------------------------------------------------
// extractLink — handler principal
// ---------------------------------------------------------------------------

const extractLink = async (req, res) => {

  console.log('[extract] method:', req.method);
  console.log('[extract] originalUrl:', req.originalUrl);
  console.log('[extract] query:', describeParams(req.query));
  console.log('[extract] body:', describeParams(req.body));

  // Extracción flexible de parámetros
  const url = firstValue(req.query.url, req.body?.url);
  const tmdbId = firstValue(
    req.query.tmdbId, req.query.id, req.query.tmdb_id,
    req.body?.tmdbId, req.body?.id, req.body?.tmdb_id
  );
  const type = firstValue(req.query.type, req.body?.type);
  const season = firstValue(req.query.season, req.body?.season);
  const episode = firstValue(req.query.episode, req.body?.episode);

  const normalizedType = String(type || 'movie').toLowerCase().trim();
  const hasDirectUrl = url && /^https?:\/\//i.test(url);

  console.log('[extract] normalized:', describeParams({
    url, tmdbId, type: normalizedType, season, episode, hasDirectUrl
  }));

  // Validación mínima
  if (!url && !tmdbId) {
    return res.status(400).json({
      success: false,
      error: 'Falta url o tmdbId',
      data: {
        candidates: [],
        debug_info: {
          reason: 'missing_identifiers',
          detail: 'Se requiere al menos una URL válida o un tmdbId'
        }
      }
    });
  }

  try {
    const result = await VideoScraper.extractStreamUrl({
      url,
      tmdbId,
      type: normalizedType,
      season,
      episode
    });

    // FIX: estructura de respuesta consistente en éxito y error.
    // Flutter siempre busca data.candidates y data.debug_info,
    // así que ambos caminos deben tener esa forma.
    if (!result.success) {
      return res.status(200).json({
        success: false,
        data: {
          candidates: [],
          debug_info: result.debug_info || {
            reason: 'no_working_providers',
            detail: 'El scraper no encontró providers funcionales'
          }
        }
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        candidates: result.candidates,
        tmdbId: result.tmdbId,
        type: result.type,
        searchMode: result.searchMode,
      }
    });

  } catch (error) {
    console.error('[extract] Error crítico:', error.message);

    return res.status(500).json({
      success: false,
      error: error.message,
      data: {
        candidates: [],
        debug_info: {
          reason: 'internal_server_error',
          detail: error.message
        }
      }
    });
  }
};

module.exports = { extractLink };