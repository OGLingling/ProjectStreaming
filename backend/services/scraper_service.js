const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');

puppeteer.use(StealthPlugin());

class VideoScraper {
  static async extractStreamUrl(targetUrl) {
    let browser;
    let streamUrl = null;

    try {
      console.log(`\n[Scraper Ultra-Reactivo] Iniciando extracción: ${targetUrl}`);
      
      browser = await puppeteer.launch({
        headless: 'new',
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-accelerated-2d-canvas',
          '--disable-gpu',
          '--mute-audio',
          '--disable-blink-features=AutomationControlled', // Evasión de Bloqueo Clave
          '--blink-settings=imagesEnabled=false'
        ],
      });

      const page = await browser.newPage();
      
      // Simulación Humana Mejorada
      await page.setViewport({ width: 1280, height: 720 });
      // Chrome v123+
      await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36');
      
      const urlObj = new URL(targetUrl);
      await page.setExtraHTTPHeaders({
        'Referer': urlObj.origin + '/',
        'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8,en-US;q=0.7'
      });

      await page.setRequestInterception(true);
      
      // Promesa central que se resuelve tan pronto como olemos el m3u8
      const urlFoundPromise = new Promise((resolve) => {
        
        page.on('request', request => {
          const url = request.url().toLowerCase();
          
          // Intercepción "Mata-Páginas"
          if (url.includes('.m3u8') || url.includes('.mp4') || url.includes('master') || url.includes('index.m3u8')) {
            if (!url.includes('audio') && !streamUrl) {
              console.log(`[Scraper] ¡BINGO! Enlace maestro capturado (Request): ${request.url().substring(0, 50)}...`);
              streamUrl = request.url();
              resolve(streamUrl); // Rompemos la promesa inmediatamente
            }
          }
          
          // Bloqueo Agresivo
          const blockTypes = ['image', 'stylesheet', 'font', 'other'];
          const isTracker = url.includes('analytics') || url.includes('ad') || url.includes('tracker');
          
          if (blockTypes.includes(request.resourceType()) || isTracker) {
            request.abort().catch(() => {});
          } else {
            request.continue().catch(() => {});
          }
        });

        // Doble Red en Responses
        page.on('response', response => {
          const url = response.url().toLowerCase();
          if ((url.includes('.m3u8') || url.includes('.mp4') || url.includes('master')) && !streamUrl) {
             if (!url.includes('audio')) {
               console.log(`[Scraper] ¡BINGO! Enlace maestro capturado (Response): ${response.url().substring(0, 50)}...`);
               streamUrl = response.url();
               resolve(streamUrl);
             }
          }
        });

      });

      // Manejo de Errores Silencioso para Goto
      // No le ponemos 'await' directo porque no queremos bloquearnos aquí
      const gotoPromise = page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 30000 })
        .catch(e => console.log("[Scraper] Goto finalizó (o timeout), pero seguimos vivos."));

      // Timer para Simulación de Interacción a los 5 segundos
      const interactionTimer = setTimeout(async () => {
        if (!streamUrl) {
          console.log(`[Scraper] Han pasado 5s sin URL. Simulando interacción humana...`);
          try { await page.mouse.click(640, 360); } catch (e) {}
        }
      }, 5000);

      // Carrera contra el tiempo (Race): Encontrar URL vs Timeout de 15s total
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error("Timeout superado (15s).")), 15000)
      );

      // La promesa se resolverá en cuanto encuentre la URL (generalmente 2-4 segs)
      const finalUrl = await Promise.race([urlFoundPromise, timeoutPromise]);
      
      clearTimeout(interactionTimer);
      return finalUrl;

    } catch (error) {
      console.error(`[Scraper] Error:`, error.message);
      throw error;
    } finally {
      if (browser) {
        console.log(`[Scraper] Apagando navegador...`);
        // Usar close() es crítico para Railway
        await browser.close().catch(() => {});
      }
    }
  }
}

module.exports = VideoScraper;
