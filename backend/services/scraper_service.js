const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const { PrismaClient } = require('@prisma/client');
const axios = require('axios');
puppeteer.use(StealthPlugin());
const prisma = new PrismaClient();

class VideoScraper {
  // --- DETECTOR AUTOMÁTICO DE PROVEEDORES ---
  static detectProvider(targetUrl) {
    const url = targetUrl.toLowerCase();
    
    if (url.includes('dood') || url.includes('/e/') || url.includes('doodstream')) {
      return 'doodstream';
    } else if (url.includes('streamtape') || url.includes('streamtape.com')) {
      return 'streamtape';
    } else if (url.includes('mixdrop') || url.includes('mixdrop.co')) {
      return 'mixdrop';
    } else if (url.includes('supervideo') || url.includes('fembed') || url.includes('feurl.com')) {
      return 'supervideo';
    } else if (url.includes('vsembed') || url.includes('vidsrc')) {
      return 'vidsrc';
    }
    
    return 'unknown';
  }

  // --- EXTRACCIÓN ESPECÍFICA POR PROVEEDOR ---
  static async extractStreamUrl(targetUrl) {
    const provider = this.detectProvider(targetUrl);
    console.log(`[Scraper] Detectado proveedor: ${provider} para URL: ${targetUrl}`);
    
    // Intentar extracción específica primero, luego fallback automático
    try {
      switch (provider) {
        case 'doodstream':
          return await this.extractDoodStream(targetUrl);
        case 'streamtape':
          return await this.extractStreamTape(targetUrl);
        case 'mixdrop':
          return await this.extractMixDrop(targetUrl);
        case 'supervideo':
          return await this.extractSuperVideo(targetUrl);
        case 'vidsrc':
          return await this.extractVidSrc(targetUrl);
        default:
          return await this.extractGeneric(targetUrl);
      }
    } catch (error) {
      console.log(`[Scraper] Error en extracción específica (${provider}): ${error.message}`);
      try {
        // Fallback a método genérico
        return await this.extractGeneric(targetUrl);
      } catch (fallbackError) {
        console.log(`[Scraper] Fallback genérico también falló: ${fallbackError.message}`);
        await this.logBrokenLink(targetUrl, fallbackError, provider);
        return null;
      }
    }
  }

  // --- MÉTODO GENÉRICO (FALLBACK) ---
  static async extractGeneric(targetUrl) {
    let browser;
    const startTime = Date.now();
    let success = false;
    let streamUrlResult = null;
    let errorMessage = null;
    
    try {
      console.log(`[Scraper Genérico] Iniciando para: ${targetUrl}`);
      browser = await puppeteer.launch({
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage', // Vital para servidores con poca RAM como Railway
          '--single-process'
        ]
      });

      const page = await browser.newPage();
      
      // Headers dinámicos basados en el origen
      const urlObj = new URL(targetUrl);
      const dynamicHeaders = {
        'Referer': urlObj.origin + '/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Connection': 'keep-alive'
      };
      await page.setExtraHTTPHeaders(dynamicHeaders);

      // Intercepción de tráfico mejorada
      await page.setRequestInterception(true);
      
      // Optimizaciones de rendimiento
      await page.setJavaScriptEnabled(true); // Habilita JS para reproductores dinámicos
      await page.setBypassCSP(true);
      await page.setCacheEnabled(false);
      
      // PROMESA DE DETECCIÓN MEJORADA
      const urlPromise = new Promise((resolve) => {
        // Detector de tráfico universal para .m3u8, .m3u, .mp4
        page.on('request', (req) => {
          const url = req.url().toLowerCase();
          
          // Captura cualquier stream de video
          if (url.includes('.m3u8') || url.includes('.m3u') || url.includes('.mp4') || 
              url.includes('master') || url.includes('index.m3u8') || url.includes('/stream/')) {
            if (!url.includes('audio') && !url.includes('trailer') && !url.includes('preview')) {
              console.log(`[Scraper] 🎯 Stream detectado (Request): ${req.url().substring(0, 80)}...`);
              resolve(req.url());
            }
          }
          
          // Política de bloqueo/permiso optimizada
          const resourceType = req.resourceType();
          const isMedia = resourceType === 'media' || resourceType === 'xhr' || resourceType === 'fetch';
          const isDocument = resourceType === 'document' || resourceType === 'websocket';
          
          if (isMedia || isDocument) {
            req.continue().catch(() => {});
          } else {
            req.abort().catch(() => {});
          }
        });

        // Doble detección en responses
        page.on('response', (res) => {
          const url = res.url().toLowerCase();
          if (url.includes('.m3u8') || url.includes('.m3u') || url.includes('.mp4') || 
              url.includes('master.m3u8') || url.includes('index.m3u8')) {
            if (!url.includes('audio')) {
              console.log(`[Scraper] 🎯 Stream detectado (Response): ${res.url().substring(0, 80)}...`);
              resolve(res.url());
            }
          }
        });
      });

      // Navegación con espera mejorada
      await page.goto(targetUrl, { 
        waitUntil: 'networkidle0', 
        timeout: 30000 
      }).catch(() => console.log('[Scraper] Navegación completada (puede haber timeouts parciales)'));

      // Interacción inteligente para activar reproductores
      const interactionTimer = setTimeout(async () => {
        try {
          console.log("[Scraper] 🤖 Simulando interacción humana...");
          // Click en el centro de la página
          await page.mouse.click(400, 300);
          // Scroll para activar lazy loading
          await page.evaluate(() => window.scrollBy(0, 200));
        } catch (interactionError) {
          console.log('[Scraper] Interacción fallida (puede ser normal):', interactionError.message);
        }
      }, 4000);

      // Timeout de 30 segundos
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error("Timeout: No se detectó stream en 30 segundos")), 30000)
      );

      const finalUrl = await Promise.race([urlPromise, timeoutPromise]);
      
      clearTimeout(interactionTimer);
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

  // --- MÉTODOS ESPECÍFICOS POR PROVEEDOR ---

  // 1. DOODSTREAM - Extracción de URLs que terminan en /e/
  static async extractDoodStream(targetUrl) {
    console.log(`[DoodStream] Iniciando extracción para: ${targetUrl}`);
    
    try {
      // Primero intentamos con el método directo de interceptación
      const directResult = await this.extractGeneric(targetUrl);
      if (directResult) return directResult;
      
      // Si falla, intentamos método específico para DoodStream
      const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
      });
      
      try {
        const page = await browser.newPage();
        await page.setExtraHTTPHeaders({
          'Referer': new URL(targetUrl).origin,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        });
        
        // Esperar a que se cargue el reproductor de DoodStream
        await page.goto(targetUrl, { waitUntil: 'networkidle0', timeout: 15000 });
        
        // Extraer URL del video de DoodStream
        const videoUrl = await page.evaluate(() => {
          // Buscar el elemento de video de DoodStream
          const videoElement = document.querySelector('video');
          if (videoElement && videoElement.src) {
            return videoElement.src;
          }
          
          // Buscar en scripts para encontrar URLs de DoodStream
          const scripts = Array.from(document.querySelectorAll('script'));
          for (const script of scripts) {
            const scriptContent = script.innerHTML;
            if (scriptContent.includes('/e/') || scriptContent.includes('doodstream')) {
              const urlMatch = scriptContent.match(/(https?:\/\/[^\s\'\"<>]+\/e\/[^\s\'\"<>]+)/);
              if (urlMatch) return urlMatch[1];
            }
          }
          
          return null;
        });
        
        if (videoUrl) {
          console.log(`[DoodStream] URL extraída: ${videoUrl}`);
          return videoUrl;
        }
        
        throw new Error('No se pudo extraer URL de DoodStream');
        
      } finally {
        await browser.close();
      }
      
    } catch (error) {
      console.log(`[DoodStream] Error: ${error.message}`);
      throw error;
    }
  }

  // 2. STREAMTAPE - Espera para que el JS cargue el atributo src
  static async extractStreamTape(targetUrl) {
    console.log(`[StreamTape] Iniciando extracción para: ${targetUrl}`);
    
    const browser = await puppeteer.launch({
      headless: 'new',
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
    });
    
    try {
      const page = await browser.newPage();
      
      // Configurar headers específicos para StreamTape
      await page.setExtraHTTPHeaders({
        'Referer': 'https://streamtape.com/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      });
      
      // Interceptar requests para capturar el stream
      let streamUrl = null;
      page.on('response', async (response) => {
        const url = response.url();
        if (url.includes('.m3u8') || url.includes('.mp4') || url.includes('/videoplayback')) {
          streamUrl = url;
          console.log(`[StreamTape] Stream detectado: ${url}`);
        }
      });
      
      // Navegar y esperar a que cargue el reproductor
      await page.goto(targetUrl, { waitUntil: 'networkidle0', timeout: 20000 });
      
      // Esperar adicionalmente para que el JS de StreamTape cargue el video
      await page.waitForTimeout(3000);
      
      // Intentar extraer la URL del video mediante evaluación
      const videoSrc = await page.evaluate(() => {
        const video = document.querySelector('video');
        if (video && video.src) {
          return video.src;
        }
        
        // Buscar en iframes
        const iframes = document.querySelectorAll('iframe');
        for (const iframe of iframes) {
          if (iframe.src && iframe.src.includes('streamtape')) {
            return iframe.src;
          }
        }
        
        return null;
      });
      
      if (videoSrc) return videoSrc;
      if (streamUrl) return streamUrl;
      
      throw new Error('No se pudo extraer URL de StreamTape');
      
    } finally {
      await browser.close();
    }
  }

  // 3. MIXDROP - Manejo de variables 'packed' y 'eval'
  static async extractMixDrop(targetUrl) {
    console.log(`[MixDrop] Iniciando extracción para: ${targetUrl}`);
    
    const browser = await puppeteer.launch({
      headless: 'new',
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
    });
    
    try {
      const page = await browser.newPage();
      
      await page.setExtraHTTPHeaders({
        'Referer': 'https://mixdrop.co/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      });
      
      // Capturar el stream mediante interceptación
      let capturedUrl = null;
      page.on('response', (response) => {
        const url = response.url();
        if (url.includes('.m3u8') || url.includes('.mp4') || url.includes('m3u8') || url.includes('mp4')) {
          capturedUrl = url;
        }
      });
      
      await page.goto(targetUrl, { waitUntil: 'networkidle0', timeout: 15000 });
      
      // Ejecutar script para desofuscar URLs de MixDrop
      const extractedUrl = await page.evaluate(() => {
        try {
          // Buscar scripts con contenido empaquetado
          const scripts = Array.from(document.querySelectorAll('script'));
          for (const script of scripts) {
            const content = script.innerHTML;
            
            // Detectar código empaquetado de MixDrop
            if (content.includes('eval(function(p,a,c,k,e,d)') || 
                content.includes('p,a,c,k,e') || 
                content.includes('mixdrop')) {
              
              // Intentar extraer URLs del código
              const urlMatches = content.match(/(https?:\/\/[^\s\'\"<>]+\.(m3u8|mp4)[^\s\'\"<>]*)/g);
              if (urlMatches) {
                return urlMatches[0];
              }
            }
          }
          
          // Buscar elemento de video directamente
          const video = document.querySelector('video');
          if (video && video.src) {
            return video.src;
          }
          
          return null;
          
        } catch (e) {
          return null;
        }
      });
      
      if (extractedUrl) return extractedUrl;
      if (capturedUrl) return capturedUrl;
      
      throw new Error('No se pudo extraer URL de MixDrop');
      
    } finally {
      await browser.close();
    }
  }

  // 4. SUPERVIDEO/FEMBED - Extracción HLS
  static async extractSuperVideo(targetUrl) {
    console.log(`[SuperVideo] Iniciando extracción para: ${targetUrl}`);
    
    try {
      // Método directo primero
      const directResult = await this.extractGeneric(targetUrl);
      if (directResult) return directResult;
      
      const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
      });
      
      try {
        const page = await browser.newPage();
        
        await page.setExtraHTTPHeaders({
          'Referer': new URL(targetUrl).origin,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'X-Requested-With': 'XMLHttpRequest'
        });
        
        // Interceptar requests HLS
        let hlsUrl = null;
        page.on('response', (response) => {
          const url = response.url();
          if (url.includes('.m3u8') || url.includes('hls') || url.includes('master.m3u8')) {
            hlsUrl = url;
          }
        });
        
        await page.goto(targetUrl, { waitUntil: 'networkidle0', timeout: 15000 });
        
        // Esperar para reproductores HLS
        await page.waitForTimeout(2000);
        
        // Buscar en el DOM para SuperVideo/Fembed
        const videoUrl = await page.evaluate(() => {
          // Buscar iframes de Fembed
          const iframes = document.querySelectorAll('iframe');
          for (const iframe of iframes) {
            if (iframe.src && (iframe.src.includes('fembed') || iframe.src.includes('supervideo'))) {
              return iframe.src;
            }
          }
          
          // Buscar elementos de video
          const video = document.querySelector('video');
          if (video && video.src) {
            return video.src;
          }
          
          // Buscar en scripts
          const scripts = Array.from(document.querySelectorAll('script'));
          for (const script of scripts) {
            const content = script.innerHTML;
            if (content.includes('m3u8') || content.includes('hls')) {
              const urlMatch = content.match(/(https?:\/\/[^\s\'\"<>]+\.m3u8[^\s\'\"<>]*)/);
              if (urlMatch) return urlMatch[0];
            }
          }
          
          return null;
        });
        
        if (videoUrl) return videoUrl;
        if (hlsUrl) return hlsUrl;
        
        throw new Error('No se pudo extraer URL de SuperVideo/Fembed');
        
      } finally {
        await browser.close();
      }
      
    } catch (error) {
      console.log(`[SuperVideo] Error: ${error.message}`);
      throw error;
    }
  }

  // 5. VIDSRC - Mantener compatibilidad con proveedores existentes
  static async extractVidSrc(targetUrl) {
    console.log(`[VidSrc] Iniciando extracción para: ${targetUrl}`);
    
    // Usar el método genérico que ya funciona bien para VidSrc
    return await this.extractGeneric(targetUrl);
  }

  // --- REGISTRO DE ENLACES ROTOS ---
  static async logBrokenLink(targetUrl, error, provider) {
    try {
      await prisma.brokenLink.create({
        data: {
          url: targetUrl,
          error: error.message,
          provider: provider,
          timestamp: new Date()
        }
      });
      console.log(`[Scraper] Enlace roto registrado: ${targetUrl}`);
    } catch (dbError) {
      console.error('[Scraper] Error al registrar enlace roto:', dbError.message);
    }
  }
}

module.exports = VideoScraper;
