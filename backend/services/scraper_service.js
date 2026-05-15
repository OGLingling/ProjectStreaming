
const path = require('path');
const fs = require('fs');

// ─── STEALTH SETUP ────────────────────────────────────────────────────────────
let chromium;
try {
  const playwrightExtra = require('playwright-extra');
  const StealthPlugin = require('puppeteer-extra-plugin-stealth');
  chromium = playwrightExtra.chromium;
  chromium.use(StealthPlugin());
  console.log('[scraper] ✅ Stealth plugin cargado');
} catch (e) {
  console.warn('[scraper] ⚠ playwright-extra no disponible, usando playwright nativo:', e.message);
  chromium = require('playwright').chromium;
}

// ─── PROXY SETUP ──────────────────────────────────────────────────────────────
const PROXIES = process.env.PROXY_LIST ? process.env.PROXY_LIST.split(',') : [];
let proxyIndex = 0;

function getNextProxy() {
  if (PROXIES.length === 0) return null;
  const proxy = PROXIES[proxyIndex % PROXIES.length];
  proxyIndex++;
  return proxy.trim();
}

// ─── CACHE LRU ───────────────────────────────────────────────────────────────
const CACHE_MAX_SIZE = 200;
const CACHE_TTL_MS = 12 * 60 * 1000;
const cache = new Map();

function cacheSet(key, value) {
  if (cache.has(key)) cache.delete(key);
  cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
  if (cache.size > CACHE_MAX_SIZE) cache.delete(cache.keys().next().value);
}

function cacheGet(key) {
  if (!cache.has(key)) return null;
  const entry = cache.get(key);
  if (!entry || entry.expiresAt <= Date.now()) { cache.delete(key); return null; }
  cache.delete(key);
  cache.set(key, entry);
  return entry.value;
}

// ─── CONSTANTES ──────────────────────────────────────────────────────────────
const INVALID_STRINGS = new Set(['null', 'undefined', 'none', 'nan', '']);

const DESKTOP_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

const AD_HOST_HINTS = [
  'doubleclick', 'googlesyndication', 'google-analytics', 'adservice',
  'adsterra', 'popads', 'propeller', 'taboola', 'sharethis',
  'dtscout', 'crwdcntrl', 'lijit', 'pxdrop', 'mgid', 'exoclick',
  'trafficjunky', 'hilltopads', 'zeropark', 'trafficstars'
];

const IFRAME_NOISE = [
  'google', 'ads', 'sharethis', 'dtscout', 'crwdcntrl',
  'lijit', 'pxdrop', 'facebook', 'twitter', 'analytics', 'recaptcha'
];

// ─── UTILS ───────────────────────────────────────────────────────────────────
const sanitize = (v) => {
  if (v === undefined || v === null) return undefined;
  const s = String(v).trim();
  return INVALID_STRINGS.has(s.toLowerCase()) ? undefined : s;
};
const isValidUrl = (s) => /^https?:\/\//i.test(String(s || ''));
const isNumericId = (s) => /^\d+$/.test(String(s || ''));
const unique = (arr) => [...new Set(arr.filter(Boolean))];

const isDirectStreamUrl = (url) => {
  const s = String(url || '').toLowerCase();
  return s.includes('.m3u8') || s.includes('.mp4') || s.includes('googlevideo.com/videoplayback');
};

const isAdOrNoiseUrl = (url) => {
  const s = String(url || '').toLowerCase();
  return AD_HOST_HINTS.some(h => s.includes(h));
};

function decodeEscapedText(text) {
  return String(text || '')
    .replace(/\\u002F/g, '/')
    .replace(/\\\//g, '/')
    .replace(/&amp;/g, '&')
    .replace(/%3A/gi, ':')
    .replace(/%2F/gi, '/')
    .replace(/%3F/gi, '?')
    .replace(/%3D/gi, '=')
    .replace(/%26/gi, '&')
    .replace(/\\n/g, '')
    .replace(/\\/g, '');
}

function extractStreamUrlsFromText(text, baseUrl) {
  const decoded = decodeEscapedText(text);
  const found = [];

  const absPattern = /https?:\/\/[^\s"'<>\\]+?(?:\.m3u8|\.mp4|videoplayback)[^\s"'<>\\]*/gi;
  for (const m of decoded.matchAll(absPattern)) found.push(m[0]);

  const relPattern = /(?:src|file|url|source|stream|hls|dash)\s*[:=]\s*["']([^"']+?(?:\.m3u8|\.mp4)[^"']*)/gi;
  for (const m of decoded.matchAll(relPattern)) {
    try { found.push(new URL(m[1], baseUrl).toString()); } catch (_) { }
  }

  const jsonPattern = /"(?:url|file|src|hls|stream|source)"\s*:\s*"([^"]+(?:\.m3u8|\.mp4)[^"]*)"/gi;
  for (const m of decoded.matchAll(jsonPattern)) {
    try { found.push(isValidUrl(m[1]) ? m[1] : new URL(m[1], baseUrl).toString()); } catch (_) { }
  }

  return unique(found.map(u => u.replace(/[),;'"\\]+$/, ''))).filter(isDirectStreamUrl);
}

// ─── WAIT HELPER ─────────────────────────────────────────────────────────────
async function waitForStreamOrTimeout(found, maxMs = 20000, intervalMs = 300) {
  const deadline = Date.now() + maxMs;
  while (Date.now() < deadline) {
    if (found.some(isDirectStreamUrl)) return true;
    await new Promise(r => setTimeout(r, intervalMs));
  }
  return found.some(isDirectStreamUrl);
}

// ─── INTERACCIÓN CON PLAYER ──────────────────────────────────────────────────
async function interactWithPlayer(page) {
  try {
    const { width, height } = page.viewportSize() || { width: 1280, height: 720 };
    
    // 1. Simular movimiento humano errático antes de interactuar
    console.log('[browser] 🖱 Simulando movimiento de ratón humano...');
    for(let i=0; i<3; i++) {
        await page.mouse.move(
            Math.random() * width, 
            Math.random() * height, 
            { steps: 5 }
        ).catch(() => {});
    }

    // 2. Intentar clics en puntos estratégicos (Centro y Cuadrantes)
    const points = [
        { x: width / 2, y: height / 2 },
        { x: width / 2 + 10, y: height / 2 + 10 },
        { x: width / 2 - 10, y: height / 2 - 10 }
    ];
    
    for (const p of points) {
        await page.mouse.click(p.x, p.y).catch(() => {});
        await page.waitForTimeout(500);
    }

    // 3. Buscar y clicar botones de Play específicos de la industria
    await page.evaluate(() => {
      const selectors = [
        'video',
        '.jw-display-icon-container', '.jw-icon-display',
        '.plyr__control--overlaid',
        '.vjs-big-play-button',
        '.play-button', '#play-button',
        '.play-icon', '.player-play-button',
        '[class*="play" i]', '[id*="play" i]',
        '[role="button"][aria-label*="play" i]',
        'button', '.overlay', '#overlay'
      ];
      
      for (const sel of selectors) {
        try {
          const elements = document.querySelectorAll(sel);
          elements.forEach(el => {
            const rect = el.getBoundingClientRect();
            if (rect.width > 0 && rect.height > 0) {
              el.click();
              // Si es un video, forzar play programático
              if (el.tagName === 'VIDEO') el.play().catch(() => {});
            }
          });
        } catch (_) {}
      }
    }).catch(() => { });

    // 4. Atajos de teclado comunes
    await page.keyboard.press('k').catch(() => {}); // YouTube/Common
    await page.keyboard.press('Space').catch(() => {});

    // 5. Scroll suave para activar Lazy Load
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(500);
    await page.mouse.wheel(0, -300);

  } catch (err) {
    console.error(`[browser] Error en interacción: ${err.message}`);
  }
}

// ─── EXTRACCIÓN DOM ──────────────────────────────────────────────────────────
async function extractFromDOM(page, baseUrl) {
  const found = [];

  const videoSrcs = await page.evaluate(() => {
    const sources = [];
    document.querySelectorAll('video').forEach(v => {
      if (v.src) sources.push(v.src);
      if (v.currentSrc) sources.push(v.currentSrc);
      v.querySelectorAll('source').forEach(s => { if (s.src) sources.push(s.src); });
    });
    document.querySelectorAll('[data-src],[data-file],[data-url],[data-stream]').forEach(el => {
      ['data-src', 'data-file', 'data-url', 'data-stream'].forEach(attr => {
        const v = el.getAttribute(attr);
        if (v) sources.push(v);
      });
    });
    return sources;
  }).catch(() => []);

  for (const src of videoSrcs) {
    try { found.push(isValidUrl(src) ? src : new URL(src, baseUrl).toString()); } catch (_) { }
  }

  const html = await page.content().catch(() => '');
  found.push(...extractStreamUrlsFromText(html, baseUrl));

  const jsVars = await page.evaluate(() => {
    const candidates = [];
    const toCheck = [
      'jwplayer', 'videojs', 'playerConfig', 'streamConfig',
      'playerSetup', 'hlsUrl', 'streamUrl', 'videoUrl', 'fileUrl'
    ];
    for (const key of toCheck) {
      try {
        const val = window[key];
        if (!val) continue;
        candidates.push(typeof val === 'string' ? val : JSON.stringify(val));
      } catch (_) { }
    }
    try {
      if (window.jwplayer) {
        const p = window.jwplayer();
        if (p?.getPlaylistItem) {
          const item = p.getPlaylistItem();
          if (item?.file) candidates.push(item.file);
          if (item?.sources) item.sources.forEach(s => candidates.push(s.file || s.src || ''));
        }
      }
    } catch (_) { }
    return candidates;
  }).catch(() => []);

  for (const text of jsVars) {
    found.push(...extractStreamUrlsFromText(text, baseUrl));
  }

  return unique(found).filter(isDirectStreamUrl);
}

// ─── BROWSER SCRAPER PRINCIPAL ───────────────────────────────────────────────
async function extractWithBrowser(embedUrl) {
  const found = [];
  let browser;
  const browserlessToken = process.env.BROWSERLESS_TOKEN;
  const scraperMode = process.env.SCRAPER_MODE || 'auto'; // 'browserless', 'local', 'auto'

  console.log(`[browser] 🛠 Modo seleccionado: ${scraperMode}`);

  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      // DECISIÓN DE MOTOR DE NAVEGACIÓN
      let useBrowserless = false;
      
      if (scraperMode === 'browserless') {
        useBrowserless = true;
      } else if (scraperMode === 'local') {
        useBrowserless = false;
      } else {
        // Modo Auto: Browserless en primer intento si hay token
        useBrowserless = (attempt === 1 && browserlessToken);
      }

      if (useBrowserless && browserlessToken) {
        console.log('[browser] ☁ Conectando a Browserless.io...');
        try {
          browser = await chromium.connectOverCDP({
            endpointURL: `wss://chrome.browserless.io?token=${browserlessToken}&stealth&--disable-notifications`,
            timeout: 25000
          });
          console.log('[browser] ✅ Conectado a Browserless');
        } catch (e) {
          console.error(`[browser] ❌ Error Browserless: ${e.message}`);
          if (scraperMode === 'browserless') break; // Si está forzado y falla, salimos
          continue; // Si es auto, intentamos el siguiente (local)
        }
      } else {
        // MODO LOCAL ("LA TUYA")
        const currentProxy = (attempt === 2) ? getNextProxy() : null;
        console.log(`[browser] 🏠 Iniciando Navegador Local ${currentProxy ? '(con Proxy)' : '(IP Directa)'}...`);
        
        browser = await chromium.launch({
          headless: true, // Cambiar a false si quieres ver qué pasa en local (solo si tienes GUI)
          proxy: currentProxy ? { server: currentProxy.startsWith('http') ? currentProxy : `http://${currentProxy}` } : undefined,
          args: [
            '--no-sandbox', 
            '--disable-setuid-sandbox', 
            '--disable-blink-features=AutomationControlled',
            '--disable-web-security',
            '--disable-features=IsolateOrigins,site-per-process'
          ]
        });
      }

      const context = await browser.newContext({ 
        userAgent: DESKTOP_UA, 
        viewport: { width: 1280, height: 720 },
        ignoreHTTPSErrors: true,
        extraHTTPHeaders: {
          'Referer': 'https://vidsrc.to/',
          'Origin': 'https://vidsrc.to/',
          'Accept-Language': 'en-US,en;q=0.9,es;q=0.8'
        }
      });
      
      context.on('request', request => {
        const u = request.url();
        if (isDirectStreamUrl(u) && !found.includes(u)) {
          console.log(`[browser] 🎯 Red: ${u.substring(0, 50)}...`);
          found.push(u);
        }
      });

      const scrapePage = async (url, level = 'L1') => {
        const page = await context.newPage();
        const screenshotsDir = path.join(__dirname, '../screenshots');
        if (!fs.existsSync(screenshotsDir)) fs.mkdirSync(screenshotsDir, { recursive: true });

        await page.route('**/*', (route) => {
          const type = route.request().resourceType();
          if (['image', 'font'].includes(type) && !isDirectStreamUrl(route.request().url())) return route.abort();
          if (AD_HOST_HINTS.some(h => route.request().url().includes(h))) return route.abort();
          route.continue();
        });

        try {
          console.log(`[browser] → ${level} Navegando: ${url}`);
          const navigationTimeout = attempt === 1 ? 35000 : 55000;
          await page.goto(url, { waitUntil: 'domcontentloaded', timeout: navigationTimeout });

          // 5. INTENTAR ACTIVAR EL REPRODUCTOR (Simular Clic Humano Aleatorio)
          console.log(`[browser] 🖱 Intentando activar reproductor con clic aleatorio...`);
          try {
            await page.waitForTimeout(Math.floor(Math.random() * 3000) + 3000); 
            
            // Clic aleatorio cerca del centro (640, 360) +/- 50px
            const randomX = 640 + (Math.floor(Math.random() * 100) - 50);
            const randomY = 360 + (Math.floor(Math.random() * 100) - 50);
            
            await page.mouse.move(randomX, randomY, { steps: 10 });
            await page.mouse.click(randomX, randomY);
            
            await page.waitForTimeout(1500);
            
            // Intentar presionar 'k' o 'Space' (atajos comunes de play)
            await page.keyboard.press('k').catch(() => {});
          } catch (e) {}

          console.log(`[browser] ⏳ Esperando captura de red (12s)...`);
          await page.waitForTimeout(12000); 

          const safeName = url.replace(/[^a-z0-9]/gi, '_').substring(0, 30);
          await page.screenshot({ path: path.join(screenshotsDir, `${level}_At${attempt}_${safeName}.png`) }).catch(() => {});

          const content = await page.content();
          if (content.includes('Sorry, you have been blocked') || content.includes('Verify you are human') || content.includes('Cloudflare')) {
            if (content.includes('Ray ID') || content.includes('challenge')) {
               console.warn(`[browser] 🛡 Bloqueo en ${level}`);
               await page.close();
               return { blocked: true, iframes: [] };
            }
          }
          
          await page.waitForTimeout(3500);
          await interactWithPlayer(page);
          await waitForStreamOrTimeout(found, 15000);

          const domUrls = await extractFromDOM(page, url);
          if (domUrls.length > 0) found.push(...domUrls);

          const iframes = await page.$$eval('iframe', el => el.map(i => i.src)).catch(() => []);
          await page.close();
          return { blocked: false, iframes: iframes.filter(s => s && s.startsWith('http') && !IFRAME_NOISE.some(n => s.includes(n))) };
        } catch (e) {
          console.error(`[browser] Error en ${level}: ${e.message}`);
          await page.close().catch(() => {});
          // Si el error es un timeout, marcamos como bloqueado para intentar otro proxy
          if (e.message.includes('timeout') || e.message.includes('net::ERR')) {
            return { blocked: true, iframes: [] };
          }
          return { blocked: false, iframes: [] };
        }
      };

      const l1 = await scrapePage(embedUrl, 'L1');
      if (l1.blocked && attempt < 3) {
        console.log('[browser] 🔄 Reintentando con IP diferente...');
        await browser.close();
        continue;
      }

      for (const l2Url of l1.iframes.slice(0, 5)) {
        if (found.length > 0) break;
        const l2 = await scrapePage(l2Url, 'L2');
        if (l2.blocked) break;
        for (const l3Url of l2.iframes.slice(0, 3)) {
           if (found.length > 0) break;
           await scrapePage(l3Url, 'L3');
        }
      }

      await browser.close();
      if (found.length > 0 || attempt === 3) break;
    } catch (err) {
      console.error(`[browser] Intento ${attempt} fallido: ${err.message}`);
      if (browser) await browser.close().catch(() => {});
      if (attempt === 3) break;
    }
  }
  return { urls: unique(found).filter(isDirectStreamUrl), error: null };
}

// ─── CLASE PRINCIPAL ──────────────────────────────────────────────────────────
class VideoScraper {
  static normalizeMediaType(value) {
    const raw = String(value || '').toLowerCase();
    return raw.includes('tv') || raw.includes('serie') ? 'tv' : 'movie';
  }

  static normalizeRequest(source) {
    const raw = source || {};
    const url = sanitize(raw.url);
    const tmdbId = sanitize(raw.tmdbId) ?? sanitize(raw.id);
    const type = this.normalizeMediaType(raw.type);
    const isTV = type === 'tv';
    const season = Number(raw.season) || 1;
    const episode = Number(raw.episode) || 1;

    if (url && isValidUrl(url)) {
      return { scenario: 'url', url, tmdbId, type, isTV, season, episode };
    }
    if (tmdbId && isNumericId(tmdbId)) {
      return { scenario: 'tmdb', url: null, tmdbId, type, isTV, season, episode };
    }
    return { scenario: 'invalid' };
  }

  static buildCandidates(n) {
    const { tmdbId, isTV, season, episode } = n;
    const tvPath = `tv/${tmdbId}/${season}/${episode}`;
    const moviePath = `movie/${tmdbId}`;

    if (isTV) {
      return [
        `https://vidsrc.to/embed/${tvPath}`,
        `https://vidsrc.me/embed/${tvPath}`,
        `https://vsembed.ru/embed/${tvPath}/`,
        `https://player.vidsrc.co/embed/${tvPath}`,
        `https://www.2embed.cc/embedtv/${tmdbId}&s=${season}&e=${episode}`,
        `https://multiembed.mov/?video_id=${tmdbId}&tmdb=1&s=${season}&e=${episode}`,
        // vidsrc.xyz eliminado — no resuelve DNS en Render
        `https://embed.smashystream.com/playere.php?tmdb=${tmdbId}&season=${season}&episode=${episode}`
      ];
    }

    return [
      `https://vidsrc.to/embed/${moviePath}`,
      `https://vidsrc.me/embed/${moviePath}`,
      `https://vsembed.ru/embed/${moviePath}/`,
      `https://player.vidsrc.co/embed/${moviePath}`,
      `https://www.2embed.cc/embed/${tmdbId}`,
      `https://multiembed.mov/?video_id=${tmdbId}&tmdb=1`,
      // vidsrc.xyz eliminado — no resuelve DNS en Render
      `https://embed.smashystream.com/playere.php?tmdb=${tmdbId}`
    ];
  }

  static async extractFromEmbed(embedUrl) {
    const debug = { embedUrl, streamsFound: 0, errors: [] };
    const result = await extractWithBrowser(embedUrl);
    debug.streamsFound = result.urls.length;
    if (result.error) debug.errors.push(result.error);
    return { urls: unique(result.urls).filter(isDirectStreamUrl), debug };
  }

  static async createPayload(source) {
    const n = this.normalizeRequest(source);

    if (n.scenario === 'invalid') {
      return { success: false, candidates: [], debug_info: { reason: 'invalid_params' } };
    }

    const cacheKey = n.scenario === 'url'
      ? `stream-url-${n.url}`
      : `stream-${n.type}-${n.tmdbId}-${n.season}-${n.episode}`;

    const cached = cacheGet(cacheKey);
    if (cached) {
      console.log(`[scraper] Cache hit: ${cacheKey}`);
      return cached;
    }

    if (n.scenario === 'url') {
      const payload = {
        success: isDirectStreamUrl(n.url),
        candidates: isDirectStreamUrl(n.url) ? [n.url] : [],
        tmdbId: n.tmdbId,
        type: n.type,
        debug_info: { source: 'direct_url' }
      };
      if (payload.success) cacheSet(cacheKey, payload);
      return payload;
    }

    const embeds = this.buildCandidates(n);
    const candidates = [];
    const debugList = [];
    const browserLimit = Number(process.env.SCRAPER_BROWSER_LIMIT) || 3;

    for (const [i, embedUrl] of embeds.entries()) {
      if (candidates.length >= 1) break;
      if (i >= browserLimit) break;

      console.log(`[scraper] Provider ${i + 1}/${Math.min(embeds.length, browserLimit)}: ${embedUrl}`);
      const result = await this.extractFromEmbed(embedUrl);
      debugList.push(result.debug);
      candidates.push(...result.urls);
    }

    const streamCandidates = unique(candidates).filter(isDirectStreamUrl);
    const payload = {
      success: streamCandidates.length > 0,
      candidates: streamCandidates,
      tmdbId: n.tmdbId,
      type: n.type,
      searchMode: true,
      debug_info: {
        embedsChecked: debugList.length,
        streamsFound: streamCandidates.length,
        providers: debugList
      }
    };

    if (payload.success) cacheSet(cacheKey, payload);
    return payload;
  }

  static async extractStreamUrl(source) {
    return await this.createPayload(source);
  }
}

module.exports = VideoScraper;