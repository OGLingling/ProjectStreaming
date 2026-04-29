const { chromium } = require('playwright'); // Cambiado a Playwright para máxima compatibilidad con Render
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

class VideoScraper {
  // --- DETECTOR AUTOMÁTICO DE PROVEEDORES (Se mantiene igual) ---
  static detectProvider(targetUrl) {
    const url = targetUrl.toLowerCase();
    if (url.includes('vidsrc.win')) return 'vidsrcwin';
    if (url.includes('dood') || url.includes('/e/') || url.includes('doodstream')) return 'doodstream';
    if (url.includes('streamtape')) return 'streamtape';
    if (url.includes('mixdrop')) return 'mixdrop';
    if (url.includes('supervideo') || url.includes('fembed')) return 'supervideo';
    if (url.includes('vsembed') || url.includes('vidsrc')) return 'vidsrc';
    return 'unknown';
  }

  static isVidSrcWinCandidate(rawUrl) {
    const url = (rawUrl || '').toLowerCase();
    const hasVideoExt = url.includes('.m3u8') || url.includes('.mp4');
    const hasExpectedToken = url.includes('playlist') || url.includes('master') || url.includes('hls');
    return hasVideoExt && hasExpectedToken && !url.includes('audio') && !url.includes('trailer');
  }

  // --- MÉTODO PRINCIPAL ADAPTADO PARA RENDER ---
  static async extractStreamUrl(targetUrl) {
    const provider = this.detectProvider(targetUrl);
    console.log(`[Scraper] Proveedor: ${provider} en Render`);

    let browser;
    const startTime = Date.now();
    let success = false;
    let streamUrlResult = null;
    let errorMessage = null;

    try {
      // Lanzamiento optimizado para la RAM limitada de Render
      browser = await chromium.launch({
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--single-process' // Crítico para no agotar la CPU de Render
        ]
      });

      const refererOrigin = new URL(targetUrl).origin;
      const context = await browser.newContext({
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        viewport: { width: 1280, height: 720 }
      });
      const page = await context.newPage();

      // Intercepción de tráfico (Equivalente a tu lógica anterior)
      const urlPromise = new Promise((resolve) => {
        page.on('request', (req) => {
          const url = req.url().toLowerCase();
          if (provider === 'vidsrcwin') {
            if (this.isVidSrcWinCandidate(url)) {
              resolve(req.url());
            }
            return;
          }
          if (url.includes('.m3u8') || url.includes('.mp4') || url.includes('master.m3u8')) {
            if (!url.includes('audio') && !url.includes('trailer')) resolve(req.url());
          }
        });
        page.on('response', (res) => {
          const url = res.url().toLowerCase();
          if (provider === 'vidsrcwin') {
            if (this.isVidSrcWinCandidate(url)) {
              resolve(res.url());
            }
            return;
          }
          if (url.includes('.m3u8') || url.includes('.mp4')) {
            resolve(res.url());
          }
        });
      });

      // Navegación rápida (waitUntil: 'domcontentloaded' es más rápido en Render)
      await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 20000 });

      // Simulación de interacción para activar reproductores (vidsrc.win)
      if (provider === 'vidsrcwin') {
        await new Promise((resolve) => setTimeout(resolve, 5000));
      }
      await page.mouse.click(400, 300);
      await page.evaluate(() => window.scrollBy(0, 200));

      // Espera el stream o el timeout
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error("Timeout: No se detectó stream en 45 segundos")), 45000)
      );

      streamUrlResult = await Promise.race([urlPromise, timeoutPromise]);
      success = true;
      return streamUrlResult;

    } catch (error) {
      console.log(`[Scraper] Error: ${error.message}`);
      errorMessage = error.message;
      await this.logBrokenLink(targetUrl, error, provider);
      return null;
    } finally {
      if (browser) {
        await browser.close(); // Siempre cerrar para liberar memoria en Render
      }
      // Guardar Log en BD
      await this.saveLog(targetUrl, success, streamUrlResult, errorMessage, Date.now() - startTime);
    }
  }

  // --- LOGS Y MANTENIMIENTO ---
  static async saveLog(url, success, result, error, duration) {
    try {
      await prisma.scrapeLog.create({
        data: { targetUrl: url, success, streamUrl: result, error, duration }
      });
    } catch (e) { console.error("Error BD Log:", e.message); }
  }

  static async logBrokenLink(targetUrl, error, provider) {
    try {
      await prisma.brokenLink.create({
        data: { url: targetUrl, error: error.message, provider, timestamp: new Date() }
      });
    } catch (e) { console.error("Error BD BrokenLink:", e.message); }
  }
}

module.exports = VideoScraper;
