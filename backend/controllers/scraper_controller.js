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

  console.log(`[extract] START -> ID: ${tmdbId}, Type: ${type}`);

  if (!tmdbId) {
    console.log('[extract] ERROR: No hay tmdbId');
    return res.status(400).json({ success: false, candidates: [], error: 'No ID' });
  }

  try {
    const result = await VideoScraper.extractStreamUrl({ tmdbId, type, season, episode });
    const candidates = result.results.map(r => r.url);

    const finalResponse = {
      success: candidates.length > 0,
      candidates: candidates,
      tmdbId: tmdbId,
      type: type,
      searchMode: true
    };

    console.log('[extract] SUCCESS: Enviando', candidates.length, 'candidatos');
    console.log('[extract] JSON FINAL:', JSON.stringify(finalResponse));

    return res.status(200).json(finalResponse);

  } catch (error) {
    console.error('[extract] CRITICAL ERROR:', error.message);
    return res.status(500).json({ success: false, candidates: [], error: error.message });
  }
};

module.exports = { extractLink };