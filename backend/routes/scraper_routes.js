const express = require('express');
const router = express.Router();
const VideoScraper = require('../services/scraper_service');

/**
 * Endpoint para extraer URL directa de video (ej. .m3u8 o .mp4)
 * URL Esperada: GET /api/extract?url=https://vsembed.ru/embed/movie?tmdb=1234
 */
router.get('/extract', async (req, res) => {
  const { url } = req.query;

  if (!url) {
    return res.status(400).json({
      success: false,
      error: "Falta el parámetro 'url'. Ejemplo: /api/extract?url=https://vsembed.ru/..."
    });
  }

  try {
    console.log(`[API] Solicitud de extracción para URL: ${url}`);
    
    // Llamar al Scraper Service
    const streamUrl = await VideoScraper.extractStreamUrl(url);

    if (streamUrl) {
      return res.status(200).json({
        success: true,
        streamUrl: streamUrl
      });
    } else {
      return res.status(404).json({
        success: false,
        error: "No se pudo extraer el enlace directo .m3u8 tras analizar el tráfico."
      });
    }

  } catch (error) {
    console.error("[API] Error del Servidor durante Scraping:", error);
    return res.status(500).json({
      success: false,
      error: "Error interno al ejecutar el extractor de video.",
      details: error.message
    });
  }
});

module.exports = router;
