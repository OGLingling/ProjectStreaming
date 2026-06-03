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
    lower.includes('master.m3u8') ||
    lower.includes('manifest.m3u8') ||
    lower.includes('application/x-mpegurl');
};

const isEmbedUrl = (url) => {
  const lower = String(url || '').toLowerCase();
  return lower.startsWith('http') && !isDirectStreamUrl(lower);
};

const normalizeUrlList = (items, predicate) => {
  if (!Array.isArray(items)) return [];
  return [...new Set(
    items
      .map((item) => (typeof item === 'string' ? item : item?.url))
      .map((item) => String(item || '').trim())
      .filter(predicate)
  )];
};

const normalizeSource = (source, index) => {
  const url = typeof source === 'string' ? source : source?.url;
  if (!isDirectStreamUrl(url)) return null;

  return {
    url,
    name: source?.name || `Server Mirror ${index + 1}`,
    quality: source?.quality || 'Auto',
    provider: source?.provider || null,
    subtitleUrl: source?.subtitleUrl || source?.subtitle_url || null,
    subtitleLanguage: source?.subtitleLanguage || source?.subtitle_language || 'es-419',
    subtitleLabel: source?.subtitleLabel || source?.subtitle_label || 'Espanol Latino',
    subtitles: Array.isArray(source?.subtitles) ? source.subtitles : []
  };
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

    const enrichedSources = Array.isArray(result.sources)
      ? result.sources.map(normalizeSource).filter(Boolean)
      : [];
    const resultCandidates = Array.isArray(result.candidates)
      ? result.candidates
      : Array.isArray(result.results)
        ? result.results.map(r => r.url).filter(Boolean)
        : [];
    const embedCandidates = normalizeUrlList(result.embedCandidates || result.embeds, isEmbedUrl);
    const mp4Candidates = normalizeUrlList(result.mp4Candidates, (candidate) => {
      const lower = String(candidate || '').toLowerCase();
      return lower.startsWith('http') &&
        (lower.includes('.mp4') || lower.includes('googlevideo.com/videoplayback'));
    });

    const candidateStrings = [...new Set([
      ...enrichedSources.map((source) => source.url),
      ...resultCandidates
    ])].filter(isDirectStreamUrl);
    const candidateObjects = candidateStrings.map((candidateUrl, index) => {
      return enrichedSources.find((source) => source.url === candidateUrl) || {
        url: candidateUrl,
        name: `Server Mirror ${index + 1}`,
        quality: 'Auto',
        subtitleUrl: null,
        subtitleLanguage: 'es-419',
        subtitleLabel: 'Espanol Latino',
        subtitles: []
      };
    });

    const finalResponse = {
      success: candidateStrings.length > 0 || embedCandidates.length > 0,
      candidates: candidateStrings, // Formato string []
      sources: candidateObjects,    // Formato objeto {}
      urls: candidateStrings,       // Backup común
      embedCandidates,
      embeds: embedCandidates,
      mp4Candidates,
      tmdbId: result.tmdbId || tmdbId || null,
      tmdb_id: tmdbId ? parseInt(tmdbId) : null,    // Lo enviamos como string y como int por si acaso
      type: type,
      searchMode: Boolean(result.searchMode),
      clientSideCheck: Boolean(result.clientSideCheck),
      debug_info: result.debug_info || null
    };

    console.log('[extract] SUCCESS: Enviando respuesta universal');
    return res.status(200).json(finalResponse);

  } catch (error) {
    console.error('[extract] ERROR:', error.message);
    return res.status(500).json({ success: false, candidates: [], error: error.message });
  }
};

module.exports = { extractLink };
