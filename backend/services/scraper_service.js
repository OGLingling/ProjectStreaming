const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

class VideoScraper {
  static async extractStreamUrl(targetUrl) {
    let browser;
    try {
      browser = await puppeteer.launch({
        headless: 'new',
        args: [
          '--no-sandbox', 
          '--disable-setuid-sandbox', 
          '--disable-dev-shm-usage',
          '--single-process' // Crucial para ahorrar RAM en Railway
        ]
      });

      const page = await browser.newPage();
      let streamUrl = null;

      await page.setRequestInterception(true);
      
      page.on('request', (req) => {
        const url = req.url();
        // Captura inmediata del archivo de video
        if (url.includes('.m3u8') || url.includes('master.m3u8')) {
          streamUrl = url;
        }
        
        // Bloqueo agresivo de recursos para que cargue en < 10s
        if (['image', 'font', 'stylesheet', 'media'].includes(req.resourceType()) || url.includes('google') || url.includes('ads')) {
          req.abort();
        } else {
          req.continue();
        }
      });

      // Navegación con tiempo límite de 25s (Railway te da hasta 30s por defecto)
      await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});

      // Si no aparece el link, hacemos un clic rápido
      if (!streamUrl) {
        await page.mouse.click(300, 300).catch(() => {});
        // Esperamos máximo 5 segundos más
        for (let i = 0; i < 25; i++) {
          if (streamUrl) break;
          await new Promise(r => setTimeout(r, 200));
        }
      }

      if (!streamUrl) throw new Error("Video no encontrado");
      return streamUrl;

    } finally {
      if (browser) await browser.close();
    }
  }
}
