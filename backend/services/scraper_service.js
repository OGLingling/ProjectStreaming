const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');

// Añadir plugin stealth para evitar bloqueos antibot (Cloudflare, etc.)
puppeteer.use(StealthPlugin());

class VideoScraper {
  /**
   * Extrae el enlace directo .m3u8 o .mp4 de un iframe de video
   * @param {string} targetUrl - URL del iframe (ej. Vidsrc o Streamwish)
   * @returns {Promise<string|null>} - El enlace del video o null si falla
   */
  static async extractStreamUrl(targetUrl) {
    let browser;
    let streamUrl = null;

    try {
      console.log(`[Scraper] Iniciando extracción para: ${targetUrl}`);
      
      // 1. Configuración del Navegador (Headless, optimizado para servidor)
      browser = await puppeteer.launch({
        headless: 'new',
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage', // Previene agotar la memoria /dev/shm en Linux
          '--disable-accelerated-2d-canvas',
          '--disable-gpu',
          '--mute-audio',
        ],
        // executablePath: process.env.PUPPETEER_EXECUTABLE_PATH // Descomenta si Railway te pide usar Chromium del sistema
      });

      const page = await browser.newPage();

      // 2. Bypass de Seguridad: Headers y User-Agent realistas
      await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      
      // Extraer el origen de la URL para usarlo como Referer
      const urlObj = new URL(targetUrl);
      await page.setExtraHTTPHeaders({
        'Referer': urlObj.origin + '/',
        'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8'
      });

      // 3. Monitoreo de Red: Interceptar peticiones buscando .m3u8 o .mp4
      await page.setRequestInterception(true);
      
      page.on('request', request => {
        const url = request.url();
        
        // Filtrar archivos maestros o streams
        if (url.includes('.m3u8') || url.includes('.mp4') || url.includes('master.m3u')) {
          // Ignorar archivos puramente de audio si el servidor los separa
          if (!url.includes('audio') && !streamUrl) {
            console.log(`[Scraper] ¡Enlace directo capturado!: ${url}`);
            streamUrl = url;
          }
        }
        
        // Bloquear imágenes y CSS para acelerar la carga (Optimización de recursos)
        if (['image', 'stylesheet', 'font'].includes(request.resourceType())) {
          request.abort();
        } else {
          request.continue();
        }
      });

      // 4. Navegación y Espera Inteligente
      // networkidle2 espera hasta que no haya más de 2 conexiones de red (la página cargó)
      await page.goto(targetUrl, { waitUntil: 'networkidle2', timeout: 30000 });

      // Simular un clic en el centro para reproductores que requieren interacción
      try {
        await page.mouse.click(500, 300);
      } catch (e) {
        // Ignorar si falla el clic
      }

      // Esperar hasta 10 segundos buscando el enlace, revisando cada 1 segundo
      for (let i = 0; i < 10; i++) {
        if (streamUrl) break;
        await new Promise(resolve => setTimeout(resolve, 1000));
      }

      return streamUrl;

    } catch (error) {
      console.error(`[Scraper] Error durante la extracción:`, error.message);
      throw error;
    } finally {
      // 5. Optimización Crítica: Cerrar el navegador SIEMPRE
      if (browser) {
        console.log(`[Scraper] Cerrando navegador para liberar memoria.`);
        await browser.close();
      }
    }
  }
}

module.exports = VideoScraper;
