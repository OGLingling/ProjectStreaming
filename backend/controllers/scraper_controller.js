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
  // Logs de auditoría para verificar qué llega desde Render
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

  const normalizedType = String(type || 'movie').toLowerCase().trim();

  console.log('[extract] Parametros normalizados:', describeParams({
    url, tmdbId, type: normalizedType, season, episode
  }));

  // Validación mínima
  if (!url && !tmdbId) {
    return res.status(400).json({
      success: false,
      candidates: [],
      debug_info: { reason: 'missing_identifiers', detail: 'Falta tmdbId' }
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

    // Mapeamos los resultados a un array simple de strings para Flutter
    const candidates = result.results ? result.results.map(r => r.url) : [];

    if (!result.success || candidates.length === 0) {
      return res.status(200).json({
        success: false,
        candidates: [],
        debug_info: {
          reason: 'empty_candidates',
          detail: 'El motor no generó candidatos para este ID'
        }
      });
    }

    /**
     * ESTRUCTURA PLANA (FIX SINCRONIZACIÓN):
     * Eliminamos el objeto "data" intermedio. 
     * Flutter ahora encontrará "success" y "candidates" en la raíz del JSON.
     */
    return res.status(200).json({
      success: true,
      candidates: candidates,
      tmdbId: result.tmdbId,
      type: result.type,
      searchMode: true,
      // Opcional: enviamos raw_results por si tu modelo de Flutter los requiere
      raw_results: result.results
    });

  } catch (error) {
    console.error('[extract] Error crítico en controlador:', error.message);

    return res.status(500).json({
      success: false,
      candidates: [],
      debug_info: {
        reason: 'internal_server_error',
        detail: error.message
      }
    });
  }
};

module.exports = { extractLink };