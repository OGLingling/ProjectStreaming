const { chromium } = require('playwright-extra');
const { stealth } = require('playwright-stealth');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Aplicar plugin de sigilo
chromium.use(stealth());

class VideoScraper {
  static NAV_TIMEOUT_MS = 100000; // 100 segundos
  static UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  /**
   * Filtro de red para detectar el archivo de video
   */
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

  /**
   * Proceso de extracción principal
   */
  static async extractFromSingleUrl(targetUrl) {
    let browser;
    try {
      const token = process.env.BROWSERLESS_TOKEN;
      
      if (token) {
        console.log("[Scraper] Conectando a Browserless (Modo Remoto)...");
        browser = await chromium.connectOverCDP(`wss://chrome.browserless.io?token=${token}`);
      } else {
        console.log("[Scraper] Ejecutando localmente (Cuidado con la RAM de Render)...");
        browser = await chromium.launch({
          args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--single-process']
        });
      }

      const context = await browser.newContext({
        userAgent: this.UA,
        viewport: { width: 1280, height: 720 }
      });

      const page = await context.newPage();
      let streamUrlFound = null;

      // Escuchar el tráfico de red en tiempo real
      page.on('request', (req) => {
        const url = req.url();
        if (this.isStreamCandidate(url)) {
          console.log("[DEBUG] ¡Video detectado!:", url);
          streamUrlFound = url;
        }
      });

      // Bloqueo de basura para acelerar la carga
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
        console.log("[Scraper] La página tardó mucho, pero intentaremos interactuar...");
      }

      // --- ESTRATEGIA DE CLICS TÁCTICOS ---
      await page.waitForTimeout(10000); // Espera inicial de 10s para el player

      if (!streamUrlFound) {
        console.log("[Scraper] Ejecutando ráfaga de clics tácticos...");
        
        const points = [
          {x: 640, y: 360}, // Centro exacto
          {x: 640, y: 300}, // Arriba centro
          {x: 640, y: 420}, // Abajo centro
          {x: 400, y: 360}, // Izquierda
          {x: 880, y: 360}  // Derecha
        ];

        for (const p of points) {
          if (streamUrlFound) break;
          console.log(`[Scraper] Clic de prueba en: ${p.x}, ${p.y}`);
          await page.mouse.click(p.x, p.y);
          await page.waitForTimeout(2500); // Pausa entre clics para dejar que el video cargue
        }
      }

      // Verificación final dinámica (esperamos hasta 30s más si es necesario)
      for (let i = 0; i < 30; i++) {
        if (streamUrlFound) return streamUrlFound;
        await page.waitForTimeout(1000);
      }

      throw new Error("No se detectó flujo de video tras múltiples intentos.");

    } finally {
      if (browser) await browser.close();
    }
  }

  static isValidHttpUrl(v) { try { return new URL(v).protocol.startsWith('http'); } catch { return false; } }

  static buildCandidates(url) {
    const raw = String(url || '').trim();
    if (this.isValidHttpUrl(raw)) return [raw];
    const id = (raw.match(/tmdb[:=]?(\d+)/i) || raw.match(/^(\d+)$/))?.[1];
    return id ? [
      `https://vidsrc.win/embed/movie/${id}`,
      `https://vidsrc.win/embed/tv/${id}/1/1`
    ] : [];
  }

  static async extractStreamUrl(url) {
    const start = Date.now();
    let res = null, err = null;
    try {
      const candidates = this.buildCandidates(url);
      for (const c of candidates) {
        console.log(`[Scraper] Probando candidato: ${c}`);
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
      console.error("Error BD Log:", err.message);
    }
  }
}

module.exports = VideoScraper;