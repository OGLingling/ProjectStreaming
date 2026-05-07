const VideoScraper = require('../services/scraper_service');

// ---------------------------------------------------------------------------
// Helpers (Mantenemos tu lógica de limpieza)
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
  console.log('[extract] Request recibida:', req.method, req.originalUrl);

  // 1. Extracción robusta de parámetros
  const url = firstValue(req.query.url, req.body?.url);
  const tmdbId = firstValue(
    req.query.tmdbId, req.query.id, req.query.tmdb_id,
    req.body?.tmdbId, req.body?.id, req.body?.tmdb_id
  );
  const type = firstValue(req.query.type, req.body?.type) || 'movie';
  const season = firstValue(req.query.season, req.body?.season);
  const episode = firstValue(req.query.episode, req.body?.episode);

  const normalizedType = String(type).toLowerCase().trim();

  // Log para depurar por qué salían undefined
  console.log('[extract] Parametros normalizados:', describeParams({
    url, tmdbId, type: normalizedType, season, episode
  }));

  // 2. Validación mínima
  if (!url && !tmdbId) {
    return res.status(400).json({
      success: false,
      candidates: [],
      error: 'Falta tmdbId o URL'
    });
  }

  try {
    // 3. Llamada al servicio
    const result = await VideoScraper.extractStreamUrl({
      url,
      tmdbId,
      type: normalizedType,
      season,
      episode
    });

    // 4. Mapeo para Flutter (Array simple de strings)
    const candidates = result.results ? result.results.map(r => r.url) : [];

    // 5. RESPUESTA PLANA (Sin objeto "data" intermedio)
    // Esto resuelve el "Error de Sincronización"
    return res.status(200).json({
      success: candidates.length > 0,
      candidates: candidates,
      tmdbId: tmdbId,
      type: normalizedType,
      searchMode: true
    });

  } catch (error) {
    console.error('[extract] Error crítico:', error.message);
    return res.status(500).json({
      success: false,
      candidates: [],
      error: error.message
    });
  }
};

module.exports = { extractLink };