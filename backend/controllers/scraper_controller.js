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
  // Logs de auditoría
  console.log('[extract] Request recibida:', req.method, req.originalUrl);

  // Extracción flexible de parámetros
  const url = firstValue(req.query.url, req.body?.url);
  const tmdbId = firstValue(
    req.query.tmdbId, req.query.id, req.query.tmdb_id,
    req.body?.tmdbId, req.body?.id, req.body?.tmdb_id
  );
  const type = firstValue(req.query.type, req.body?.type);
  const season = firstValue(req.query.season, req.body?.season);
  const episode = firstValue(req.query.episode, req.body?.episode);

  // Normalización básica para logs
  const normalizedType = String(type || 'movie').toLowerCase().trim();

  console.log('[extract] Parametros normalizados:', describeParams({
    url, tmdbId, type: normalizedType, season, episode
  }));

  // Validación mínima: Si no hay ID ni URL, no hay nada que buscar
  if (!url && !tmdbId) {
    return res.status(400).json({
      success: false,
      data: {
        candidates: [],
        debug_info: { reason: 'missing_identifiers', detail: 'Se requiere tmdbId' }
      }
    });
  }

  try {
    // Llamada al servicio (que ya no hace Health Checks bloqueantes)
    const result = await VideoScraper.extractStreamUrl({
      url,
      tmdbId,
      type: normalizedType,
      season,
      episode
    });

    /**
     * ADAPTACIÓN PARA FLUTTER:
     * El servicio devuelve 'results' (objetos url+headers).
     * Mantenemos la compatibilidad con tu frontend transformando 'results' a 'candidates'.
     */
    const candidates = result.results ? result.results.map(r => r.url) : [];

    if (!result.success || candidates.length === 0) {
      return res.status(200).json({
        success: false,
        data: {
          candidates: [],
          debug_info: {
            reason: 'empty_candidates',
            detail: 'El motor no generó candidatos para este ID'
          }
        }
      });
    }

    // Respuesta exitosa
    return res.status(200).json({
      success: true,
      data: {
        candidates: candidates, // Array de strings para tu lógica actual de Flutter
        raw_results: result.results, // Por si decides usar los headers en el futuro
        tmdbId: result.tmdbId,
        type: result.type,
        searchMode: true
      }
    });

  } catch (error) {
    console.error('[extract] Error crítico en controlador:', error.message);

    return res.status(500).json({
      success: false,
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