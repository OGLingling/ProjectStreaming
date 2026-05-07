const VideoScraper = require('../services/scraper_service');

const INVALID_STRINGS = new Set(['null', 'undefined', 'none', 'nan', '']);

const firstValue = (...values) => {
  return values.find((item) => {
    if (item === undefined || item === null) return false;
    const s = String(item).toLowerCase().trim();
    return s !== '' && !INVALID_STRINGS.has(s);
  });
};

const extractLink = async (req, res) => {
  const tmdbId = firstValue(req.query.tmdbId, req.query.id, req.body?.tmdbId);
  const type = firstValue(req.query.type, req.body?.type) || 'movie';
  const season = firstValue(req.query.season, req.body?.season);
  const episode = firstValue(req.query.episode, req.body?.episode);

  console.log(`[extract] Procesando ID: ${tmdbId} (${type})`);

  if (!tmdbId) {
    return res.status(400).json({
      success: false,
      candidates: [],
      error: 'ID de TMDB requerido'
    });
  }

  try {
    const result = await VideoScraper.extractStreamUrl({
      tmdbId,
      type: type.toLowerCase(),
      season: parseInt(season),
      episode: parseInt(episode)
    });

    // Mapeo simple: de objetos {url, headers} a solo strings de URL
    const candidates = result.results.map(r => r.url);

    // RESPUESTA PLANA PARA FLUTTER
    return res.status(200).json({
      success: true,
      candidates: candidates,
      tmdbId: result.tmdbId,
      type: result.type,
      searchMode: true
    });

  } catch (error) {
    console.error('[extract] Error:', error.message);
    return res.status(500).json({
      success: false,
      candidates: [],
      error: error.message
    });
  }
};

module.exports = { extractLink };