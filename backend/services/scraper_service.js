const { chromium } = require('playwright');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

class VideoScraper {
  // Aumentamos el tiempo a 80s: Render es lento y los sitios de streaming tienen muchos scripts.
  static NAV_TIMEOUT_MS = 80000; 
  static UA_WINDOWS_CHROME =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static detectProvider(targetUrl) {
    const url = String(targetUrl || '').toLowerCase();
    if (url.includes('vidsrc.win')) return 'vidsrcwin';
    if (url.includes('dood') || url.includes('/e/') || url.includes('doodstream')) return 'doodstream';
    if (url.includes('streamtape')) return 'streamtape';
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
    // Bloqueo de dominios de publicidad para no saturar la RAM de Render
    if (url.includes('googleads') || url.includes('doubleclick') || url.includes('analytics') || url.includes('popads')) return false;
    
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
          '--disable-dev-shm-usage', // Esencial para evitar crashes en Render
          '--single-process',       // Reduce el consumo de RAM significativamente
          '--no-zygote',
          '--disable-blink-features=AutomationControlled'
        ]
      });

      const context = await browser.newContext({
        userAgent: this.UA_WINDOWS_CHROME,
        viewport: { width: 1280, height: 720 }
      });

      const page = await context.newPage();
      let streamUrlFound = null;

      // OPTIMIZACIÓN AGRESIVA: Bloqueamos basura pesada
      await page.route('**/*', (route) => {
        const url = route.request().url();
        const type = route.request().resourceType();
        
        // Si ya tenemos el video, abortamos cualquier otra petición entrante
        if (streamUrlFound) return route.abort();

        // Bloqueamos imágenes, fuentes y trackers
        if (['image', 'font', 'media'].includes(type) && !url.includes('.mp4')) {
          return route.abort();
        }
        if (url.includes('ads') || url.includes('tracking') || url.includes('fb-cdn') || url.includes('analytics')) {
          return route.abort();
        }
        route.continue();
      });

      // Escuchador de red en tiempo real
      page.on('request', (req) => {
        const url = req.url();
        if (this.isStreamCandidate(url)) {
          console.log("[DEBUG] ¡Video encontrado en la red!:", url);
          streamUrlFound = url;
        }
      });

      try {
        // Usamos domcontentloaded para no esperar a que carguen los anuncios
        await page.goto(targetUrl, { 
          waitUntil: 'domcontentloaded', 
          timeout: this.NAV_TIMEOUT_MS 
        });
      } catch (e) {
        console.log("[Scraper] Timeout en carga, pero verificando si se capturó el stream...");
      }

      // SIMULACIÓN DE HUMANO: Muchos reproductores no sueltan el link sin un clic
      await page.waitForTimeout(4000);
      if (!streamUrlFound) {
        console.log("[Scraper] Intentando clic de activación en el reproductor...");
        await page.mouse.click(640, 360); // Clic al centro de la pantalla
        await page.waitForTimeout(2000);
        await page.mouse.wheel(0, 300); // Pequeño scroll
      }

      // Espera final dinámica
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
        console.log(`[Scraper] Probando: ${candidate}`);
        try {
          const stream = await this.extractFromSingleUrl(candidate);
          if (stream) {
            success = true;
            streamUrlResult = stream;
            break;
          }
        } catch (e) {
          console.error(`[Scraper] Falló candidato: ${e.message}`);
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
        data: { 
          targetUrl: url, 
          success, 
          streamUrl: result, 
          error: error || null, 
          duration 
        }
      });
    } catch (e) {
      console.error('Error BD Log:', e.message);
    }
  }
}

module.exports = VideoScraper;