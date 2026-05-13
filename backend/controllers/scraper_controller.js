const VideoScraper = require('../services/scraper_service');

const INVALID_STRINGS = new Set(['null', 'undefined', 'none', 'nan', '']);

const firstValue = (...values) => {
  return values.find((item) => {
    if (item === undefined || item === null) return false;
    const s = String(item).toLowerCase().trim();
    return s !== '' && !INVALID_STRINGS.has(s);
  });
};

const isDirectStreamUrl = (url) => {
  const lower = String(url || '').toLowerCase();
  return lower.includes('.m3u8') ||
    lower.includes('.mp4') ||
    lower.includes('googlevideo.com/videoplayback');
};

const extractLink = async (req, res) => {
  const tmdbId = firstValue(req.query.tmdbId, req.query.id, req.body?.tmdbId);
  const url = firstValue(req.query.url, req.body?.url);
  const type = (firstValue(req.query.type, req.body?.type) || 'movie').toLowerCase();
  const season = parseInt(firstValue(req.query.season, req.body?.season)) || 1;
  const episode = parseInt(firstValue(req.query.episode, req.body?.episode)) || 1;

  console.log(`[extract] Iniciando para ID: ${tmdbId || 'direct-url'}`);

  if (!tmdbId && !url) {
    return res.status(400).json({ success: false, candidates: [], error: 'No ID or URL' });
  }

  try {
    const result = await VideoScraper.extractStreamUrl({ url, tmdbId, type, season, episode });

    const resultCandidates = Array.isArray(result.candidates)
      ? result.candidates
      : Array.isArray(result.results)
        ? result.results.map(r => r.url).filter(Boolean)
        : [];

    const candidateStrings = [...new Set(resultCandidates)].filter(isDirectStreamUrl);
    const candidateObjects = candidateStrings.map((candidateUrl, index) => ({
      url: candidateUrl,
      name: `Server Mirror ${index + 1}`,
      quality: 'Auto'
    }));

    const finalResponse = {
      success: true,
      candidates: candidateStrings, // Formato string []
      sources: candidateObjects,    // Formato objeto {}
      urls: candidateStrings,       // Backup común
      tmdbId: result.tmdbId || tmdbId || null,
      tmdb_id: tmdbId ? parseInt(tmdbId) : null,    // Lo enviamos como string y como int por si acaso
      type: type,
      searchMode: Boolean(result.searchMode),
      clientSideCheck: Boolean(result.clientSideCheck)
    };

    console.log('[extract] SUCCESS: Enviando respuesta universal');
    return res.status(200).json(finalResponse);

  } catch (error) {
    console.error('[extract] ERROR:', error.message);
    return res.status(500).json({ success: false, candidates: [], error: error.message });
  }
};

module.exports = { extractLink };
