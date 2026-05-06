const VideoScraper = require('../services/scraper_service');

const describeParams = (params) => Object.fromEntries(
  Object.entries(params || {}).map(([key, value]) => [
    key,
    {
      value,
      type: Array.isArray(value) ? 'array' : typeof value
    }
  ])
);

const isPositiveIntegerLike = (value) => {
  if (value === undefined || value === null || value === '') return false;
  return Number.isInteger(Number(value)) && Number(value) > 0;
};

// Strings que nunca deben considerarse valores válidos (Dart null.toString(), etc.)
const _INVALID_STRINGS = new Set(['null', 'undefined', 'none', 'nan']);

const firstValue = (...values) => {
  const value = values.find((item) => {
    if (item === undefined || item === null) return false;
    const s = String(item).toLowerCase().trim();
    return s !== '' && !_INVALID_STRINGS.has(s);
  });
  return Array.isArray(value) ? value[0] : value;
};

const extractLink = async (req, res) => {
  console.log('[extract] method:', req.method);
  console.log('[extract] originalUrl:', req.originalUrl);
  console.log('[extract] query:', describeParams(req.query));
  console.log('[extract] body:', describeParams(req.body));

  const url = firstValue(req.query.url, req.body?.url);
  const tmdbId = firstValue(
    req.query.tmdbId,
    req.query.id,
    req.query.tmdb_id,
    req.body?.tmdbId,
    req.body?.id,
    req.body?.tmdb_id
  );
  const type = firstValue(req.query.type, req.body?.type);
  const season = firstValue(req.query.season, req.body?.season);
  const episode = firstValue(req.query.episode, req.body?.episode);

  console.log('[extract] normalized:', describeParams({ url, tmdbId, type, season, episode }));

  if (!url && !tmdbId) {
    return res.status(400).json({
      success: false,
      error: 'Falta el parametro requerido: tmdbId o url',
      received: {
        query: describeParams(req.query),
        body: describeParams(req.body),
        acceptedIdNames: ['tmdbId', 'id', 'tmdb_id']
      }
    });
  }

  if (tmdbId && !isPositiveIntegerLike(tmdbId)) {
    return res.status(400).json({
      success: false,
      error: 'Parametro invalido: tmdbId debe ser un numero entero positivo',
      hint: 'Asegúrate de que el campo tmdbId en tu base de datos no sea NULL y sea un ID numérico válido de TMDB',
      received: describeParams({ tmdbId })
    });
  }

  const normalizedType = String(type || 'movie').toLowerCase().trim();
  const isTV = normalizedType.includes('tv') || normalizedType.includes('serie');

  if (isTV && !isPositiveIntegerLike(season)) {
    return res.status(400).json({
      success: false,
      error: 'Parametro invalido o faltante: season debe ser un numero entero positivo para contenido tv',
      received: describeParams({ type, season })
    });
  }

  if (isTV && !isPositiveIntegerLike(episode)) {
    return res.status(400).json({
      success: false,
      error: 'Parametro invalido o faltante: episode debe ser un numero entero positivo para contenido tv',
      received: describeParams({ type, episode })
    });
  }

  try {
    const result = await VideoScraper.extractStreamUrl({
      url,
      tmdbId,
      type,
      season,
      episode
    });

    if (!result || !Array.isArray(result.candidates) || result.candidates.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'No hay candidatos disponibles para este recurso'
      });
    }

    return res.status(200).json({
      success: true,
      data: result
    });
  } catch (error) {
    console.error('Error en Scraper Controller:', error.message);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
};

module.exports = { extractLink };
