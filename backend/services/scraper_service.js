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
      
      // Simulación Humana Mejorada: Viewport y User-Agent
      await page.setViewport({ width: 1280, height: 720 });
      await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      
      const urlObj = new URL(targetUrl);
      await page.setExtraHTTPHeaders({
        'Referer': urlObj.origin + '/',
        'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8,en-US;q=0.7'
      });

      // Optimización Extrema: Bloquear todo lo innecesario
      await page.setRequestInterception(true);
      
      // Intercepción Agresiva en Peticiones
      page.on('request', request => {
        const url = request.url().toLowerCase();
        
        // 1. Capturar el stream en la fase de REQUEST
        if (url.includes('.m3u8') || url.includes('.mp4') || url.includes('master')) {
          if (!url.includes('audio') && !streamUrl) {
            console.log(`[Scraper] ¡BINGO! Enlace maestro capturado (Request): ${request.url().substring(0, 50)}...`);
            streamUrl = request.url();
          }
        }
        
        // 2. Bloquear basura (anuncios, trackers, css, fuentes, imágenes)
        const blockTypes = ['image', 'stylesheet', 'font', 'other'];
        const isTracker = url.includes('analytics') || url.includes('ad') || url.includes('tracker');
        
        // Cuidado: No bloquees 'media' ni 'xhr' ni 'fetch'
        if (blockTypes.includes(request.resourceType()) || isTracker) {
          request.abort();
        } else {
          request.continue();
        }
      });

      // Intercepción Agresiva en Respuestas (A veces la URL real se esconde en redirecciones o responses)
      page.on('response', response => {
        const url = response.url().toLowerCase();
        if ((url.includes('.m3u8') || url.includes('.mp4') || url.includes('master')) && !streamUrl) {
           if (!url.includes('audio')) {
             console.log(`[Scraper] ¡BINGO! Enlace maestro capturado (Response): ${response.url().substring(0, 50)}...`);
             streamUrl = response.url();
           }
        }
      });

      // Navegación rápida: Aumentamos timeout a 30s pero esperamos menos eventos de red
      const gotoPromise = page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 30000 }).catch(e => console.log("[Scraper] Goto Warning:", e.message));
      
      // Bucle de chequeo ultra-rápido (cada 200ms) para cerrar apenas encuentre la URL
      for (let i = 0; i < 150; i++) { // 30 segundos máximo (150 * 200ms)
        if (streamUrl) {
          console.log(`[Scraper] Enlace encontrado. Abortando carga de página para ahorrar memoria.`);
          break; 
        }
        
        // Simular clic por si el player necesita interacción (al segundo 3 y 6)
        if (i === 15 || i === 30) {
          try { await page.mouse.click(640, 360); } catch (e) {}
        }
        
        await new Promise(r => setTimeout(r, 200));
      }

      // No necesitamos esperar a que page.goto termine si ya tenemos la URL
      
      if (!streamUrl) {
        throw new Error("Timeout superado (30s): El script no pudo encontrar un archivo .m3u8 o master en la red.");
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
