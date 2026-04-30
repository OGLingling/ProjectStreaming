const { chromium } = require('playwright-extra');
const { stealth } = require('playwright-stealth');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

chromium.use(stealth());

class VideoScraper {
  static NAV_TIMEOUT_MS = 90000;
  static UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static isStreamCandidate(rawUrl) {
    const url = String(rawUrl || '').toLowerCase();
    if (url.includes('googleads') || url.includes('analytics')) return false;
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
      const token = process.env.BROWSERLESS_TOKEN;
      
      if (token) {
        console.log("[Scraper] Conectando a Browserless...");
        // Conexión remota: El navegador NO corre en Render
        browser = await chromium.connectOverCDP(`wss://chrome.browserless.io?token=${token}`);
      } else {
        console.log("[Scraper] Token no hallado, intentando ejecución local...");
        browser = await chromium.launch({ args: ['--no-sandbox', '--disable-setuid-sandbox'] });
      }

      const context = await browser.newContext({ userAgent: this.UA });
      const page = await context.newPage();
      let streamUrlFound = null;

      page.on('request', (req) => {
        if (this.isStreamCandidate(req.url())) {
          streamUrlFound = req.url();
        }
      });

      // Ir directamente al grano
      await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: this.NAV_TIMEOUT_MS });
      
      // Espera de seguridad e interacción
      await page.waitForTimeout(6000);
      if (!streamUrlFound) {
        await page.mouse.click(640, 360);
        await page.waitForTimeout(3000);
      }

      for (let i = 0; i < 20; i++) {
        if (streamUrlFound) return streamUrlFound;
        await page.waitForTimeout(1000);
      }

      throw new Error("No se detectó flujo de video.");

    } finally {
      if (browser) await browser.close();
    }
  }

  // --- Mantenemos tus funciones auxiliares ---
  static buildCandidates(url) {
    const raw = String(url || '').trim();
    const id = (raw.match(/tmdb[:=]?(\d+)/i) || raw.match(/^(\d+)$/))?.[1];
    return id ? [`https://vidsrc.win/embed/movie/${id}`, `https://vidsrc.win/embed/tv/${id}/1/1`] : [raw];
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
    try { await prisma.scrapeLog.create({ data: { targetUrl: u, success: s, streamUrl: r, error: e, duration: d } }); } catch {}
  }
}

module.exports = VideoScraper;