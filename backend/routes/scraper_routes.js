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
    console.log(`\n[API] Recibiendo petición de scraping para: ${url}`);
    
    // Llamar al Scraper Service Ultra-Ligero
    const streamUrl = await VideoScraper.extractStreamUrl(url);

    if (streamUrl) {
      return res.status(200).json({
        success: true,
        streamUrl: streamUrl
      });
    }
    
    // Si llegamos aquí, el scraper no encontró URL pero tampoco lanzó error
    return res.status(404).json({
      success: false,
      error: "No se encontró ningún stream de video en la página",
      details: "El scraper completó la búsqueda pero no detectó archivos .m3u8 o .mp4"
    });

  } catch (error) {
    console.error("[API] Error capturado durante Scraping:", error.message);
    
    // Respuesta JSON detallada y amigable para Flutter
    return res.status(500).json({
      success: false,
      error: "No se pudo extraer el enlace del video.",
      details: error.message
    });
  }
});

module.exports = router;
