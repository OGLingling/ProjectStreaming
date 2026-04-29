const { chromium } = require('playwright');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

class VideoScraper {
  // 1. AUMENTO DE TIEMPO: Render necesita al menos 60s para cargar estas webs
  static NAV_TIMEOUT_MS = 60000; 
  static UA_WINDOWS_CHROME =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static detectProvider(targetUrl) {
    const url = String(targetUrl || '').toLowerCase();
    if (url.includes('vidsrc.win')) return 'vidsrcwin';
    if (url.includes('dood') || url.includes('/e/') || url.includes('doodstream')) return 'doodstream';
    if (url.includes('streamtape')) return 'streamtape';
    if (url.includes('mixdrop')) return 'mixdrop';
    if (url.includes('supervideo') || url.includes('fembed')) return 'supervideo';
    if (url.includes('vsembed') || url.includes('vidsrc')) return 'vidsrc';
    return 'unknown';
  }

  static isValidHttpUrl(value) {
    try {
      const parsed = new URL(value);
      return parsed.protocol === 'http:' || parsed.protocol === 'https:';
    } catch (_) {
      return false;
    }
  }

  static buildCandidates(targetUrl) {
    const raw = String(targetUrl || '').trim();
    if (this.isValidHttpUrl(raw)) return [raw];

    const tmdbMatch = raw.match(/tmdb[:=]?(\d+)/i) || raw.match(/^(\d{2,10})$/);
    if (!tmdbMatch) return [];

    const id = tmdbMatch[1];
    return [
      `https://vidsrc.win/embed/movie/${id}`,
      `https://vidsrc.win/embed/tv/${id}/1/1`
    ];
  }

  static isStreamCandidate(rawUrl) {
    const url = String(rawUrl || '').toLowerCase();
    if (url.includes('googleads') || url.includes('doubleclick') || url.includes('analytics')) return false;
    return (
      url.includes('.m3u8') || 
      url.includes('.mp4') || 
      url.includes('master.m3u8') || 
      url.includes('playlist.m3u8')
    );
  }

  static async runDeepInteractions(page) {
    console.log("[Scraper] Iniciando interacciones profundas...");
    const frames = page.frames();
    const playerFrame = frames.find(f => f.url().includes('vidsrc') || f.url().includes('embed'));

    if (playerFrame) {
      try {
        await playerFrame.click('body', { position: { x: 400, y: 300 }, force: true });
      } catch (e) {
        await page.mouse.click(400, 300);
      }
    } else {
      await page.mouse.click(400, 300);
    }
    await page.waitForTimeout(2000);
  }

  static async extractFromSingleUrl(targetUrl) {
    let browser;
    try {
      browser = await chromium.launch({
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage', // CRÍTICO para Render
          '--single-process',       // Ahorra RAM
          '--no-zygote',            // Evita procesos huérfanos
          '--disable-blink-features=AutomationControlled'
        ]
      });

      const context = await browser.newContext({
        userAgent: this.UA_WINDOWS_CHROME,
        viewport: { width: 1280, height: 720 }
      });

      const page = await context.newPage();
      let streamUrlFound = null;

      // 2. OPTIMIZACIÓN: Bloqueamos imágenes y fuentes para cargar más rápido
      await page.route('**/*', (route) => {
        const type = route.request().resourceType();
        if (['image', 'font', 'media'].includes(type) && !route.request().url().includes('.mp4')) {
          route.abort();
        } else {
          route.continue();
        }
      });

      page.on('request', (req) => {
        const url = req.url();
        if (this.isStreamCandidate(url)) {
          console.log("[DEBUG] Stream detectado:", url);
          streamUrlFound = url;
        }
      });

      // 3. ESPERA EXTENDIDA: networkidle para asegurar que carguen los reproductores
      await page.goto(targetUrl, { 
        waitUntil: 'networkidle', 
        timeout: this.NAV_TIMEOUT_MS 
      });

      await this.runDeepInteractions(page);

      // Revisión de 15 segundos para dar tiempo a que el flujo aparezca
      for (let i = 0; i < 15; i++) {
        if (streamUrlFound) return streamUrlFound;
        await page.waitForTimeout(1000);
      }

      throw new Error("No se detectó flujo de video tras interacciones.");

    } finally {
      if (browser) await browser.close();
    }
  }

  static async extractStreamUrl(targetUrl) {
    const startTime = Date.now();
    let success = false;
    let streamUrlResult = null;
    let errorMessage = null;

    try {
      const candidates = this.buildCandidates(targetUrl);
      if (!candidates.length) throw new Error('ID o URL inválida');

      for (const candidate of candidates) {
        console.log(`[Scraper] Probando candidato: ${candidate}`);
        try {
          const stream = await this.extractFromSingleUrl(candidate);
          if (stream) {
            success = true;
            streamUrlResult = stream;
            break;
          }
        } catch (e) {
          console.error(`[Scraper] Error en candidato: ${e.message}`);
          errorMessage = e.message;
        }
      }
      return streamUrlResult;
    } catch (error) {
      errorMessage = error.message;
      return null;
    } finally {
      await this.saveLog(String(targetUrl), success, streamUrlResult, errorMessage, Date.now() - startTime);
    }
  }

  static async saveLog(url, success, result, error, duration) {
    try {
      await prisma.scrapeLog.create({
        data: { targetUrl: url, success, streamUrl: result, error, duration }
      });
    } catch (e) {
      console.error('Error BD Log:', e.message);
    }
  }
}

module.exports = VideoScraper;