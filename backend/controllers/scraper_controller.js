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

const extractLink = async (req, res) => {
  console.log('[extract] method:', req.method);
  console.log('[extract] originalUrl:', req.originalUrl);
  console.log('[extract] query:', describeParams(req.query));
  console.log('[extract] body:', describeParams(req.body));

  const { url, tmdbId, type, season, episode } = req.query;

  if (!url && !tmdbId) {
    return res.status(400).json({
      success: false,
      error: 'Falta el parametro requerido: tmdbId o url',
      received: {
        query: describeParams(req.query),
        body: describeParams(req.body)
      }
    });
  }

  if (tmdbId && !isPositiveIntegerLike(tmdbId)) {
    return res.status(400).json({
      success: false,
      error: 'Parametro invalido: tmdbId debe ser un numero entero positivo',
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
