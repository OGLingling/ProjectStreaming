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
  const type = (firstValue(req.query.type, req.body?.type) || 'movie').toLowerCase();
  const season = parseInt(firstValue(req.query.season, req.body?.season)) || 1;
  const episode = parseInt(firstValue(req.query.episode, req.body?.episode)) || 1;

  console.log(`[extract] Iniciando para ID: ${tmdbId}`);

  if (!tmdbId) {
    return res.status(400).json({ success: false, candidates: [], error: 'No ID' });
  }

  try {
    const result = await VideoScraper.extractStreamUrl({ tmdbId, type, season, episode });

    // Generamos ambos formatos: Lista de strings y Lista de objetos
    const candidateStrings = result.results.map(r => r.url);
    const candidateObjects = result.results.map(r => ({
      url: r.url,
      name: 'Server Mirror',
      quality: 'Auto'
    }));

    const finalResponse = {
      success: true,
      candidates: candidateStrings, // Formato string []
      sources: candidateObjects,    // Formato objeto {}
      urls: candidateStrings,       // Backup común
      tmdbId: tmdbId,
      tmdb_id: parseInt(tmdbId),    // Lo enviamos como string y como int por si acaso
      type: type,
      searchMode: true
    };

    console.log('[extract] SUCCESS: Enviando respuesta universal');
    return res.status(200).json(finalResponse);

  } catch (error) {
    console.error('[extract] ERROR:', error.message);
    return res.status(500).json({ success: false, candidates: [], error: error.message });
  }
};

module.exports = { extractLink };