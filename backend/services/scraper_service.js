const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

class VideoScraper {
  static async extractStreamUrl(targetUrl) {
    let browser;
    try {
      console.log(`[Scraper Reactivo] Iniciando para: ${targetUrl}`);
      browser = await puppeteer.launch({
        headless: 'new',
        args: [
          '--no-sandbox', 
          '--disable-setuid-sandbox', 
          '--disable-dev-shm-usage',
          '--single-process', // Ahorro de RAM
          '--disable-blink-features=AutomationControlled' // Evasión
        ]
      });

      const page = await browser.newPage();
      
      // Simulación de usuario
      await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
      const urlObj = new URL(targetUrl);
      await page.setExtraHTTPHeaders({ 'Referer': urlObj.origin + '/' });

      await page.setRequestInterception(true);
      
      // MODO REACTIVO: Promesa que se resuelve en cuanto olemos el video
      const urlPromise = new Promise((resolve) => {
        page.on('request', (req) => {
          const url = req.url().toLowerCase();
          
          // 1. Intercepción "Mata-Páginas"
          if (url.includes('.m3u8') || url.includes('master') || url.includes('.mp4')) {
            if (!url.includes('audio')) {
              console.log(`[Scraper] BINGO (Request): ${url.substring(0, 60)}...`);
              resolve(req.url()); // Retornamos la URL original sin .toLowerCase()
            }
          }
          
          // 2. Optimización Agresiva
          const resourceType = req.resourceType();
          const isTrash = ['image', 'stylesheet', 'font'].includes(resourceType) || 
                          url.includes('analytics') || url.includes('ad');
          
          // Nota: No bloqueamos 'media' porque ahí podría estar el m3u8 en algunos servers
          if (isTrash) {
            req.abort().catch(() => {});
          } else {
            req.continue().catch(() => {});
          }
        });

        // Doble Red en Responses
        page.on('response', (res) => {
          const url = res.url().toLowerCase();
          if (url.includes('.m3u8') || url.includes('master') || url.includes('.mp4')) {
            if (!url.includes('audio')) {
              console.log(`[Scraper] BINGO (Response): ${url.substring(0, 60)}...`);
              resolve(res.url());
            }
          }
        });
      });

      // Navegamos pero NO hacemos 'await' a la promesa de navegación
      // La ignoramos y la dejamos correr en segundo plano
      page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});

      // Simulación de interacción si a los 5 segundos no hay URL
      const clickTimer = setTimeout(() => {
        console.log("[Scraper] Simulando clic humano...");
        page.mouse.click(640, 360).catch(() => {});
      }, 5000);

      // Carrera: Encontrar URL vs Timeout de Seguridad (15s total para no colgar el server)
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error("Timeout: No se encontró el m3u8")), 15000)
      );

      const finalUrl = await Promise.race([urlPromise, timeoutPromise]);
      
      clearTimeout(clickTimer);
      return finalUrl;

    } catch (error) {
      console.log(`[Scraper] Error controlado: ${error.message}`);
      throw error; // Lo atrapamos en la ruta
    } finally {
      if (browser) {
        console.log(`[Scraper] Cerrando Chromium...`);
        await browser.close().catch(() => {});
      }
    }
  }
}

module.exports = VideoScraper;
