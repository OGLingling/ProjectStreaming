const VideoScraper = require('../services/scraper_service');

const extractLink = async (req, res) => {
  const { url } = req.query;

  if (!url) {
    return res.status(400).json({
      success: false,
      error: 'URL o ID TMDB requerido'
    });
  }

  try {
    const result = await VideoScraper.extractStreamUrl(url);

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
