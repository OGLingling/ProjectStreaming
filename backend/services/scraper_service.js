const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

class VideoScraper {
  static async extractStreamUrl(targetUrl) {
    let browser;
    try {
      browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu']
      });

      const page = await browser.newPage();
      let streamUrl = null;

      // Intercepción inmediata
      await page.setRequestInterception(true);
      page.on('request', (req) => {
        const url = req.url();
        // Si encontramos el video, guardamos y cancelamos el resto para ganar velocidad
        if (url.includes('.m3u8') || url.includes('master.m3u8') || url.includes('.mp4')) {
          if (!url.includes('audio')) {
            streamUrl = url;
          }
        }
        
        // Bloqueo total de basura para liberar CPU en Railway
        if (['image', 'font', 'stylesheet'].includes(req.resourceType())) {
          req.abort();
        } else {
          req.continue();
        }
      });

      // Navegación rápida: No esperamos a que la página cargue totalmente
      // 'domcontentloaded' es mucho más rápido que 'networkidle'
      await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 20000 }).catch(() => {});

      // Bucle de chequeo ultra-rápido (máximo 12 segundos reales)
      for (let i = 0; i < 60; i++) {
        if (streamUrl) break;
        // Al segundo 3, forzamos un clic por si el player está dormido
        if (i === 15) await page.mouse.click(300, 300).catch(() => {});
        await new Promise(r => setTimeout(r, 200));
      }

      if (!streamUrl) throw new Error("Timeout: No se detectó stream en 15s");
      return streamUrl;

    } finally {
      if (browser) await browser.close();
    }
  }
}

module.exports = VideoScraper;