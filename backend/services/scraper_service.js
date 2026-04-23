const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const { PrismaClient } = require('@prisma/client');
puppeteer.use(StealthPlugin());
const prisma = new PrismaClient();

class VideoScraper {
  static async extractStreamUrl(targetUrl) {
    let browser;
    const startTime = Date.now();
    let success = false;
    let streamUrlResult = null;
    let errorMessage = null;
    
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
      
      // Simulación de usuario ultra-ligera
      await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
      const urlObj = new URL(targetUrl);
      await page.setExtraHTTPHeaders({ 'Referer': urlObj.origin + '/' });

      // BLOQUEO EXTREMO DE RECURSOS - VITAL PARA RAILWAY
      await page.setRequestInterception(true);
      
      // Deshabilitar características que consumen RAM
      await page.setJavaScriptEvaluation(false);
      await page.setBypassCSP(false);
      await page.setCacheEnabled(false);
      
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
          
          // 2. OPTIMIZACIÓN EXTREMA - BLOQUEO MASIVO PARA RAILWAY
          const resourceType = req.resourceType();
          const requestUrl = req.url().toLowerCase();
          
          // PERMITIR SOLO: HTML, XHR, Fetch, Media (donde puede estar el m3u8) y WebSocket
          const allowedTypes = ['document', 'xhr', 'fetch', 'media', 'websocket'];
          
          // BLOQUEAR ABSOLUTAMENTE TODO LO DEMÁS
          const isAllowed = allowedTypes.includes(resourceType) || 
                           requestUrl.includes('.m3u8') || requestUrl.includes('.mp4') ||
                           requestUrl.includes('master.m3u8') || requestUrl.includes('index.m3u8');
          
          if (!isAllowed) {
            // Bloqueo agresivo: imágenes, CSS, fuentes, scripts, analytics, ads, etc.
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

      // TIMEOUT ULTRA-AGRESIVO: 12 segundos máximo para evitar límites de Railway
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error("Timeout Railway: No se encontró el stream en 12s")), 12000)
      );

      const finalUrl = await Promise.race([urlPromise, timeoutPromise]);
      
      clearTimeout(clickTimer);
      success = true;
      streamUrlResult = finalUrl;
      return finalUrl;

    } catch (error) {
      console.log(`[Scraper] Error controlado: ${error.message}`);
      errorMessage = error.message;
      throw error; // Lo atrapamos en la ruta
    } finally {
      const duration = Date.now() - startTime;
      
      // Loggear en base de datos
      try {
        await prisma.scrapeLog.create({
          data: {
            targetUrl: targetUrl,
            success: success,
            streamUrl: streamUrlResult,
            error: errorMessage,
            duration: duration
          }
        });
        console.log(`[Scraper] Log guardado en BD - Éxito: ${success}, Duración: ${duration}ms`);
      } catch (dbError) {
        console.error('[Scraper] Error al guardar log en BD:', dbError.message);
      }
      
      if (browser) {
        console.log(`[Scraper] Cerrando Chromium...`);
        await browser.close().catch(() => {});
      }
    }
  }
}

module.exports = VideoScraper;
