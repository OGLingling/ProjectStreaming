const { chromium } = require('playwright');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

class VideoScraper {
  // Aumentamos a 90 segundos para dar margen a la CPU limitada de Render
  static NAV_TIMEOUT_MS = 90000; 
  static UA_WINDOWS_CHROME = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  /**
   * Detecta si una URL de la red es un posible flujo de video
   */
  static isStreamCandidate(rawUrl) {
    const url = String(rawUrl || '').toLowerCase();
    // Bloqueo de dominios de rastreo y anuncios para ahorrar CPU
    if (url.includes('googleads') || url.includes('analytics') || url.includes('doubleclick') || url.includes('popads')) return false;
    
    return (
      url.includes('.m3u8') || 
      url.includes('.mp4') || 
      url.includes('playlist.m3u8') ||
      url.includes('master.m3u8') ||
      url.includes('video_file')
    );
  }

  /**
   * Lógica de extracción para una URL específica
   */
  static async extractFromSingleUrl(targetUrl) {
    let browser;
    try {
      browser = await chromium.launch({
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage', // Crítico para evitar crashes en Render
          '--single-process',       // Ahorra RAM al usar un solo proceso para el navegador
          '--no-zygote',
        ]
      });

      const context = await browser.newContext({
        userAgent: this.UA_WINDOWS_CHROME,
        viewport: { width: 1280, height: 720 },
        extraHTTPHeaders: { 'Referer': 'https://vsembed.ru/' } // Engaña a los servidores de video
      });

      const page = await context.newPage();
      let streamUrlFound = null;

      // Intercepción de red optimizada
      await page.route('**/*', (route) => {
        const url = route.request().url();
        const type = route.request().resourceType();
        
        // Si ya tenemos el video, detenemos cualquier otra carga
        if (streamUrlFound) return route.abort(); 

        // Bloqueo de recursos pesados (imágenes y fuentes) para liberar RAM
        if (['image', 'font'].includes(type)) return route.abort();
        if (url.includes('ads') || url.includes('tracking')) return route.abort();
        
        route.continue();
      });

      // Escuchador de eventos de red
      page.on('request', (req) => {
        const url = req.url();
        if (this.isStreamCandidate(url)) {
          console.log("[DEBUG] ¡Stream capturado!:", url);
          streamUrlFound = url;
        }
      });

      try {
        // 'commit' inicia la búsqueda en cuanto el servidor responde
        await page.goto(targetUrl, { 
          waitUntil: 'commit', 
          timeout: this.NAV_TIMEOUT_MS 
        });
      } catch (e) {
        console.log("[Scraper] Timeout en carga inicial, verificando capturas de red...");
      }

      // --- SIMULACIÓN DE INTERACCIÓN HUMANA ---
      await page.waitForTimeout(5000);
      
      if (!streamUrlFound) {
        console.log("[Scraper] Forzando clics de activación...");
        // Movimiento de scroll para activar scripts perezosos
        await page.mouse.wheel(0, 300);
        await page.waitForTimeout(1000);
        
        // Intentar clic en el centro del reproductor para disparar el evento Play
        const clickPoints = [[640, 360], [500, 300], [750, 400]];
        for (const [x, y] of clickPoints) {
          if (streamUrlFound) break;
          await page.mouse.click(x, y);
          await page.waitForTimeout(2000);
        }
      }

      // Verificación final dinámica (espera hasta 25 segundos adicionales)
      for (let i = 0; i < 25; i++) {
        if (streamUrlFound) return streamUrlFound;
        await page.waitForTimeout(1000);
      }

      throw new Error("No se detectó flujo de video tras interacciones.");

    } finally {
      if (browser) await browser.close();
    }
  }

  /**
   * Valida si el input es una URL HTTP válida
   */
  static isValidHttpUrl(value) {
    try {
      const parsed = new URL(value);
      return parsed.protocol === 'http:' || parsed.protocol === 'https:';
    } catch (_) { return false; }
  }

  /**
   * Construye las URLs candidatas basadas en el ID de TMDB o URL directa
   */
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

  /**
   * Punto de entrada principal para la extracción
   */
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
          console.error(`[Scraper] Error: ${e.message}`);
          errorMessage = e.message;
        }
      }
      return streamUrlResult;
    } catch (error) {
      errorMessage = error.message;
      return null;
    } finally {
      // Guardar log en la base de datos
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