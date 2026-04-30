const { chromium } = require('playwright-extra');
const { stealth } = require('playwright-stealth'); // Corregido
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Aplicar el plugin de sigilo a Playwright
chromium.use(stealth());

class VideoScraper {
  static NAV_TIMEOUT_MS = 100000; 
  static UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static isStreamCandidate(rawUrl) {
    const url = String(rawUrl || '').toLowerCase();
    if (url.includes('googleads') || url.includes('analytics') || url.includes('doubleclick')) return false;
    return (
      url.includes('.m3u8') || 
      url.includes('.mp4') || 
      url.includes('playlist.m3u8') ||
      url.includes('master.m3u8')
    );
  }

  static async extractFromSingleUrl(targetUrl) {
    let browser;
    try {
      browser = await chromium.launch({
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--single-process',
          '--no-zygote',
        ]
      });

      const context = await browser.newContext({
        userAgent: this.UA,
        viewport: { width: 1280, height: 720 },
      });

      const page = await context.newPage();
      let streamUrlFound = null;

      // Intercepción de red
      page.on('request', (req) => {
        const url = req.url();
        if (this.isStreamCandidate(url)) {
          streamUrlFound = url;
        }
      });

      // Bloqueo de anuncios para no saturar la RAM de Render
      await page.route('**/*', (route) => {
        const url = route.request().url();
        if (url.includes('ads') || url.includes('pop') || url.includes('pixel')) {
          return route.abort();
        }
        route.continue();
      });

      console.log(`[Scraper] Navegando a: ${targetUrl}`);
      
      try {
        await page.goto(targetUrl, { 
          waitUntil: 'domcontentloaded', 
          timeout: this.NAV_TIMEOUT_MS 
        });
      } catch (e) {
        console.log("[Scraper] Timeout en carga, pero verificando red...");
      }

      // Espera inicial para que cargue el player
      await page.waitForTimeout(8000);

      if (!streamUrlFound) {
        console.log("[Scraper] Intentando activar video con clics tácticos...");
        // Coordenadas donde suelen estar los botones de Play
        const points = [[640, 360], [600, 300], [680, 400]];
        for (const [x, y] of points) {
          if (streamUrlFound) break;
          await page.mouse.click(x, y);
          await page.waitForTimeout(2500);
        }
      }

      // Verificación final dinámica
      for (let i = 0; i < 25; i++) {
        if (streamUrlFound) return streamUrlFound;
        await page.waitForTimeout(1000);
      }

      throw new Error("No se detectó flujo de video.");

    } finally {
      if (browser) await browser.close();
    }
  }

  static isValidHttpUrl(v) { try { return new URL(v).protocol.startsWith('http'); } catch { return false; } }

  static buildCandidates(url) {
    const raw = String(url || '').trim();
    if (this.isValidHttpUrl(raw)) return [raw];
    const id = (raw.match(/tmdb[:=]?(\d+)/i) || raw.match(/^(\d+)$/))?.[1];
    return id ? [`https://vidsrc.win/embed/movie/${id}`, `https://vidsrc.win/embed/tv/${id}/1/1`] : [];
  }

  static async extractStreamUrl(url) {
    const start = Date.now();
    let res = null, err = null;
    try {
      const candidates = this.buildCandidates(url);
      for (const c of candidates) {
        res = await this.extractFromSingleUrl(c);
        if (res) break;
      }
    } catch (e) { err = e.message; }
    await this.saveLog(url, !!res, res, err, Date.now() - start);
    return res;
  }

  static async saveLog(u, s, r, e, d) {
    try { 
      await prisma.scrapeLog.create({ 
        data: { targetUrl: u, success: s, streamUrl: r, error: e, duration: d } 
      }); 
    } catch (err) {
      console.error("Error guardando log:", err.message);
    }
  }
}

module.exports = VideoScraper;