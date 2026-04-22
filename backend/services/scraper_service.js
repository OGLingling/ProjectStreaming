const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');

puppeteer.use(StealthPlugin());

class VideoScraper {
  static async extractStreamUrl(targetUrl) {
    let browser;
    let streamUrl = null;

    try {
      console.log(`[Scraper Ultra-Ligero] Iniciando extracción: ${targetUrl}`);
      
      browser = await puppeteer.launch({
        headless: 'new',
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-accelerated-2d-canvas',
          '--disable-gpu',
          '--mute-audio',
          '--blink-settings=imagesEnabled=false' // Hard block de imágenes a nivel motor
        ],
      });

      const page = await browser.newPage();

      // Headers de Identidad Críticos
      await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      const urlObj = new URL(targetUrl);
      await page.setExtraHTTPHeaders({
        'Referer': urlObj.origin + '/',
        'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8'
      });

      // Optimización Extrema: Bloquear todo lo innecesario
      await page.setRequestInterception(true);
      
      page.on('request', request => {
        const url = request.url().toLowerCase();
        
        // 1. Capturar el stream
        if (url.includes('.m3u8') || url.includes('.mp4') || url.includes('master')) {
          if (!url.includes('audio') && !streamUrl) {
            console.log(`[Scraper] ¡BINGO! Enlace maestro capturado: ${request.url().substring(0, 50)}...`);
            streamUrl = request.url(); // Guardamos la URL original con sus mayúsculas/minúsculas intactas
          }
        }
        
        // 2. Bloquear basura (anuncios, trackers, css, fuentes, imágenes)
        const blockTypes = ['image', 'stylesheet', 'font', 'media', 'other'];
        const isTracker = url.includes('analytics') || url.includes('ad') || url.includes('tracker');
        
        if (blockTypes.includes(request.resourceType()) || isTracker) {
          request.abort();
        } else {
          request.continue();
        }
      });

      // Navegación rápida (solo esperamos domcontentloaded, no toda la red)
      const gotoPromise = page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });
      
      // Bucle de chequeo ultra-rápido (cada 200ms) para cerrar apenas encuentre la URL
      for (let i = 0; i < 75; i++) { // 15 segundos máximo (75 * 200ms)
        if (streamUrl) {
          console.log(`[Scraper] Enlace encontrado. Abortando carga de página para ahorrar memoria.`);
          break; 
        }
        
        // Simular clic por si el player necesita interacción (al segundo 2 y 4)
        if (i === 10 || i === 20) {
          try { await page.mouse.click(500, 300); } catch (e) {}
        }
        
        await new Promise(r => setTimeout(r, 200));
      }

      // No necesitamos esperar a que page.goto termine si ya tenemos la URL
      
      if (!streamUrl) {
        throw new Error("Timeout superado (15s): El script no pudo encontrar un archivo .m3u8 o master en la red.");
      }

      return streamUrl;

    } catch (error) {
      console.error(`[Scraper] Error Fatal:`, error.message);
      throw error;
    } finally {
      if (browser) {
        console.log(`[Scraper] Apagando motor de Chromium...`);
        await browser.close();
      }
    }
  }
}

module.exports = VideoScraper;
