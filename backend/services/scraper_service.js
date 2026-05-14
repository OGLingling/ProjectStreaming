// services/scraper_service.js
// Scraper de streams con playwright-extra + stealth plugin.
// Detecta .m3u8 / .mp4 interceptando requests, responses y evaluando el DOM.

// ─── STEALTH SETUP ────────────────────────────────────────────────────────────
// playwright-extra + puppeteer-extra-plugin-stealth esquiva la detección de bots
let chromium;
try {
  const playwrightExtra = require('playwright-extra');
  const StealthPlugin   = require('puppeteer-extra-plugin-stealth');
  chromium = playwrightExtra.chromium;
  chromium.use(StealthPlugin());
  console.log('[scraper] ✅ Stealth plugin cargado correctamente');
} catch (e) {
  console.warn('[scraper] ⚠ playwright-extra no disponible, usando playwright nativo:', e.message);
  chromium = require('playwright').chromium;
}

// ─── CACHE LRU ───────────────────────────────────────────────────────────────
const CACHE_MAX_SIZE = 200;
const CACHE_TTL_MS   = 12 * 60 * 1000; // 12 minutos en memoria
const cache          = new Map();

function cacheSet(key, value) {
  if (cache.has(key)) cache.delete(key);
  cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
  if (cache.size > CACHE_MAX_SIZE) cache.delete(cache.keys().next().value);
}

function cacheGet(key) {
  if (!cache.has(key)) return null;
  const entry = cache.get(key);
  if (!entry || entry.expiresAt <= Date.now()) { cache.delete(key); return null; }
  cache.delete(key); cache.set(key, entry);
  return entry.value;
}

// ─── CONSTANTES ──────────────────────────────────────────────────────────────
const INVALID_STRINGS = new Set(['null', 'undefined', 'none', 'nan', '']);

// User-Agent de Chrome desktop real (más compatible que mobile para players)
const DESKTOP_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

const MOBILE_UA =
  'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

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

const isValidUrl    = (s) => /^https?:\/\//i.test(String(s || ''));
const isNumericId   = (s) => /^\d+$/.test(String(s || ''));
const unique        = (arr) => [...new Set(arr.filter(Boolean))];

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
    .replace(/\\\//g,    '/')
    .replace(/&amp;/g,   '&')
    .replace(/%3A/gi,    ':')
    .replace(/%2F/gi,    '/')
    .replace(/%3F/gi,    '?')
    .replace(/%3D/gi,    '=')
    .replace(/%26/gi,    '&')
    .replace(/\\n/g,     '')
    .replace(/\\/g,      '');
}

/**
 * Extrae URLs de stream de cualquier texto (HTML, JSON, JS).
 * Maneja URLs absolutas y relativas, encoded y escapadas.
 */
function extractStreamUrlsFromText(text, baseUrl) {
  const decoded = decodeEscapedText(text);
  const found   = [];

  // Patrón 1: URL absoluta que contiene .m3u8 o .mp4 o videoplayback
  const absPattern = /https?:\/\/[^\s"'<>\\]+?(?:\.m3u8|\.mp4|videoplayback)[^\s"'<>\\]*/gi;
  for (const m of decoded.matchAll(absPattern)) found.push(m[0]);

  // Patrón 2: atributo src/file/url/source con valor relativo
  const relPattern = /(?:src|file|url|source|stream|hls|dash)\s*[:=]\s*["']([^"']+?(?:\.m3u8|\.mp4)[^"']*)/gi;
  for (const m of decoded.matchAll(relPattern)) {
    try { found.push(new URL(m[1], baseUrl).toString()); } catch (_) {}
  }

  // Patrón 3: propiedad JSON como {"url":"...m3u8..."}
  const jsonPattern = /"(?:url|file|src|hls|stream|source)"\s*:\s*"([^"]+(?:\.m3u8|\.mp4)[^"]*)"/gi;
  for (const m of decoded.matchAll(jsonPattern)) {
    try { found.push(isValidUrl(m[1]) ? m[1] : new URL(m[1], baseUrl).toString()); } catch (_) {}
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
  // 1. Click en el centro de la pantalla (donde suele estar el play overlay)
  try {
    const { width, height } = page.viewportSize() || { width: 1280, height: 720 };
    await page.mouse.click(width / 2, height / 2);
  } catch (_) {}

  // 2. Click en selectores conocidos de players
  await page.evaluate(() => {
    const selectors = [
      'video',
      '.jw-display-icon-container',
      '.jw-icon-display',
      '.plyr__control--overlaid',
      '.vjs-big-play-button',
      '.play-button',
      '[class*="play"]',
      '[id*="play"]',
      '[role="button"]',
      'button',
      '.overlay',
      '#overlay'
    ];
    for (const sel of selectors) {
      const el = document.querySelector(sel);
      if (el) { el.click(); return el.tagName; }
    }
  }).catch(() => {});

  // 3. Tecla Space (inicia reproducción en muchos players)
  await page.keyboard.press('Space').catch(() => {});

  // 4. Intentar forzar play en el elemento <video>
  await page.evaluate(() => {
    const video = document.querySelector('video');
    if (video) {
      video.muted = true;
      video.play().catch(() => {});
      return video.src || video.currentSrc || '';
    }
    return null;
  }).catch(() => {});
}

// ─── EXTRACCIÓN DOM ──────────────────────────────────────────────────────────
/**
 * Extrae stream URLs directamente del DOM:
 * - video.src / video.currentSrc
 * - source[src]
 * - atributos data-* con URLs
 * - texto del HTML completo
 */
async function extractFromDOM(page, baseUrl) {
  const found = [];

  // a) video element sources
  const videoSrcs = await page.evaluate(() => {
    const sources = [];
    document.querySelectorAll('video').forEach(v => {
      if (v.src) sources.push(v.src);
      if (v.currentSrc) sources.push(v.currentSrc);
      v.querySelectorAll('source').forEach(s => { if (s.src) sources.push(s.src); });
    });
    // También buscar en atributos data-src, data-file, data-url
    document.querySelectorAll('[data-src],[data-file],[data-url],[data-stream]').forEach(el => {
      ['data-src', 'data-file', 'data-url', 'data-stream'].forEach(attr => {
        const v = el.getAttribute(attr);
        if (v) sources.push(v);
      });
    });
    return sources;
  }).catch(() => []);

  for (const src of videoSrcs) {
    try { found.push(isValidUrl(src) ? src : new URL(src, baseUrl).toString()); } catch (_) {}
  }

  // b) Buscar en el HTML completo del DOM renderizado
  const html = await page.content().catch(() => '');
  found.push(...extractStreamUrlsFromText(html, baseUrl));

  // c) Evaluar variables JS globales comunes de players
  const jsVars = await page.evaluate(() => {
    const candidates = [];
    const toCheck = ['jwplayer', 'videojs', 'playerConfig', 'streamConfig',
                     'playerSetup', 'hlsUrl', 'streamUrl', 'videoUrl', 'fileUrl'];
    for (const key of toCheck) {
      try {
        const val = window[key];
        if (!val) continue;
        const str = typeof val === 'string' ? val : JSON.stringify(val);
        candidates.push(str);
      } catch (_) {}
    }
    // También revisar setup de jwplayer
    try {
      if (window.jwplayer) {
        const p = window.jwplayer();
        if (p && p.getPlaylistItem) {
          const item = p.getPlaylistItem();
          if (item?.file) candidates.push(item.file);
          if (item?.sources) item.sources.forEach(s => candidates.push(s.file || s.src || ''));
        }
      }
    } catch (_) {}
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

  try {
    browser = await chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-web-security',
        '--disable-features=IsolateOrigins,site-per-process',
        '--allow-running-insecure-content',
        '--autoplay-policy=no-user-gesture-required',
        '--disable-blink-features=AutomationControlled', // extra anti-detección
        '--window-size=1280,720'
      ]
    });

    const context = await browser.newContext({
      userAgent: DESKTOP_UA,
      viewport:  { width: 1280, height: 720 },
      hasTouch:  false,
      isMobile:  false,
      javaScriptEnabled:  true,
      ignoreHTTPSErrors:  true
      // Nota: autoplay se gestiona con --autoplay-policy en los args de launch
    });

    // Ocultar señales de automatización que no cubre stealth
    await context.addInitScript(() => {
      Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
      Object.defineProperty(navigator, 'plugins',   { get: () => [1, 2, 3, 4, 5] });
      Object.defineProperty(navigator, 'languages', { get: () => ['es-ES', 'es', 'en-US', 'en'] });
      window.chrome = { runtime: {} };
    });

    // ── Función interna para scrapear una página ─────────────────────────────
    async function scrapePage(url, refererUrl = null) {
      const page = await context.newPage();

      const effectiveReferer = refererUrl && isValidUrl(refererUrl)
        ? refererUrl
        : `${new URL(url).origin}/`;
      const effectiveOrigin  = refererUrl && isValidUrl(refererUrl)
        ? new URL(refererUrl).origin
        : new URL(url).origin;

      await page.setExtraHTTPHeaders({
        'Referer':          effectiveReferer,
        'Origin':           effectiveOrigin,
        'Accept-Language':  'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept':           'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Sec-Fetch-Site':   'cross-site',
        'Sec-Fetch-Mode':   'navigate',
        'Sec-Fetch-Dest':   'iframe'
      });

      // ── INTERCEPTAR REQUESTS ────────────────────────────────────────────
      await page.route('**/*', async (route) => {
        const reqUrl  = route.request().url();
        const resType = route.request().resourceType();

        if (isDirectStreamUrl(reqUrl) && !isAdOrNoiseUrl(reqUrl)) {
          found.push(reqUrl);
          console.log(`[browser] ✅ Stream (route/req): ${reqUrl.substring(0, 90)}`);
        }

        // Bloquear recursos pesados que no aportan
        if (['font', 'image', 'stylesheet'].includes(resType) || isAdOrNoiseUrl(reqUrl)) {
          return route.abort();
        }
        return route.continue();
      });

      // ── INTERCEPTAR RESPONSES (crítico: aquí vienen las URLs en JSON) ───
      page.on('response', async (response) => {
        try {
          const resUrl = response.url();
          const ct     = String(response.headers()['content-type'] || '').toLowerCase();

          // Si la response misma ES el stream
          if (isDirectStreamUrl(resUrl) && !isAdOrNoiseUrl(resUrl)) {
            found.push(resUrl);
            console.log(`[browser] ✅ Stream (response URL): ${resUrl.substring(0, 90)}`);
          }

          // Buscar en cuerpos JSON/JS (aquí suelen venir las URLs en API calls)
          if (
            (ct.includes('json') || ct.includes('javascript') || ct.includes('text')) &&
            !isAdOrNoiseUrl(resUrl)
          ) {
            const body = await response.text().catch(() => '');
            if (body.includes('.m3u8') || body.includes('.mp4')) {
              const extracted = extractStreamUrlsFromText(body, resUrl);
              if (extracted.length > 0) {
                found.push(...extracted);
                console.log(`[browser] ✅ Stream(s) en body de ${resUrl.substring(0, 70)}: ${extracted.length}`);
              }
            }
          }
        } catch (_) {}
      });

      // ── TAMBIÉN capturar desde el event de request (redundante pero seguro)
      page.on('request', (req) => {
        const reqUrl = req.url();
        if (isDirectStreamUrl(reqUrl) && !isAdOrNoiseUrl(reqUrl)) {
          found.push(reqUrl);
        }
      });

      // ── NAVEGAR ─────────────────────────────────────────────────────────
      console.log(`[browser] → Navegando: ${url}`);
      try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
      } catch (e) {
        if (!e.message.toLowerCase().includes('timeout')) {
          await page.close().catch(() => {});
          throw e;
        }
        console.log(`[browser] goto timeout ignorado: ${url}`);
      }

      // ── ESPERAR SELECTOR DEL PLAYER ─────────────────────────────────────
      await page.waitForSelector(
        'video, iframe, .jw-video, .jw-display, .plyr, .vjs-tech, [class*="player"], [id*="player"]',
        { timeout: 8000 }
      ).catch(() => {});

      // Pequeña pausa para que los scripts iniciales terminen
      await page.waitForTimeout(1500);

      // ── INTERACTUAR CON EL PLAYER ────────────────────────────────────────
      await interactWithPlayer(page);

      // ── ESPERA ADAPTATIVA (hasta stream o 20s) ───────────────────────────
      await waitForStreamOrTimeout(found, 20000);

      // ── SI AÚN NO HAY STREAM: extraer del DOM ────────────────────────────
      if (!found.some(isDirectStreamUrl)) {
        console.log(`[browser] DOM extraction en: ${url}`);
        const domUrls = await extractFromDOM(page, url);
        if (domUrls.length > 0) {
          found.push(...domUrls);
          console.log(`[browser] ✅ DOM encontró: ${domUrls.length} URL(s)`);
        }
      }

      // ── SI AÚN NO: segundo click e intento ──────────────────────────────
      if (!found.some(isDirectStreamUrl)) {
        await interactWithPlayer(page);
        await waitForStreamOrTimeout(found, 10000);
      }

      // ── EXTRAER IFRAMES para el siguiente nivel ──────────────────────────
      const iframes = await page.evaluate(() =>
        [...document.querySelectorAll('iframe[src]')]
          .map(f => f.src)
          .filter(s => s && s.startsWith('http'))
      ).catch(() => []);

      await page.close().catch(() => {});

      return iframes.filter(u => !IFRAME_NOISE.some(n => u.toLowerCase().includes(n)));
    }

    // ── NIVEL 1 ────────────────────────────────────────────────────────────
    console.log(`[browser] L1: ${embedUrl}`);
    const l1Iframes = await scrapePage(embedUrl, null);
    console.log(`[browser] L1 iframes:`, l1Iframes);

    // ── NIVEL 2 ────────────────────────────────────────────────────────────
    if (!found.some(isDirectStreamUrl) && l1Iframes.length > 0) {
      const PRIORITY = ['vsembed', 'cloudnestra', 'vidsrc', 'embedrise', 'filemoon', 'doodstream'];
      const sorted = [...l1Iframes].sort((a, b) => {
        const ai = PRIORITY.findIndex(h => a.includes(h));
        const bi = PRIORITY.findIndex(h => b.includes(h));
        return (ai === -1 ? 99 : ai) - (bi === -1 ? 99 : bi);
      });

      for (const iframeUrl of sorted.slice(0, 4)) {
        if (found.some(isDirectStreamUrl)) break;
        console.log(`[browser] L2: ${iframeUrl}`);
        try {
          const l2Iframes = await scrapePage(iframeUrl, embedUrl);
          console.log(`[browser] L2 iframes:`, l2Iframes);

          // ── NIVEL 3 ────────────────────────────────────────────────────
          if (!found.some(isDirectStreamUrl) && l2Iframes.length > 0) {
            for (const deepUrl of l2Iframes.slice(0, 3)) {
              if (found.some(isDirectStreamUrl)) break;
              console.log(`[browser] L3: ${deepUrl}`);
              try { await scrapePage(deepUrl, iframeUrl); } catch (e) {
                console.log(`[browser] L3 error: ${e.message}`);
              }
            }
          }
        } catch (e) {
          console.log(`[browser] L2 error: ${e.message}`);
        }
      }
    }

    await context.close();

  } catch (error) {
    console.error(`[browser] Error crítico en ${embedUrl}: ${error.message}`);
    return { urls: unique(found).filter(isDirectStreamUrl), error: error.message };
  } finally {
    if (browser) await browser.close().catch(() => {});
  }

  const result = unique(found).filter(isDirectStreamUrl);
  console.log(`[browser] Total streams encontrados: ${result.length}${result.length > 0 ? ' → ' + result[0].substring(0, 60) : ''}`);
  return { urls: result, error: null };
}

// ─── CLASE PRINCIPAL ──────────────────────────────────────────────────────────
class VideoScraper {
  static normalizeMediaType(value) {
    const raw = String(value || '').toLowerCase();
    return raw.includes('tv') || raw.includes('serie') ? 'tv' : 'movie';
  }

  static normalizeRequest(source) {
    const raw     = source || {};
    const url     = sanitize(raw.url);
    const tmdbId  = sanitize(raw.tmdbId) ?? sanitize(raw.id);
    const type    = this.normalizeMediaType(raw.type);
    const isTV    = type === 'tv';
    const season  = Number(raw.season)  || 1;
    const episode = Number(raw.episode) || 1;

    if (url && isValidUrl(url)) {
      return { scenario: 'url', url, tmdbId, type, isTV, season, episode };
    }
    if (tmdbId && isNumericId(tmdbId)) {
      return { scenario: 'tmdb', url: null, tmdbId, type, isTV, season, episode };
    }
    return { scenario: 'invalid' };
  }

  /**
   * Construye candidatos de embed ordenados del más al menos confiable.
   * Se intenta primero los que históricamente funcionan mejor.
   */
  static buildCandidates(n) {
    const { tmdbId, isTV, season, episode } = n;
    const tvPath    = `tv/${tmdbId}/${season}/${episode}`;
    const moviePath = `movie/${tmdbId}`;
    const path      = isTV ? tvPath : moviePath;

    const candidates = [];

    if (isTV) {
      candidates.push(
        // Tier 1: players directos (menos intermediarios)
        `https://vidsrc.to/embed/${tvPath}`,
        `https://vidsrc.me/embed/${tvPath}`,
        `https://vsembed.ru/embed/${tvPath}/`,
        `https://player.vidsrc.co/embed/${tvPath}`,
        // Tier 2: otros embeds
        `https://www.2embed.cc/embedtv/${tmdbId}&s=${season}&e=${episode}`,
        `https://multiembed.mov/?video_id=${tmdbId}&tmdb=1&s=${season}&e=${episode}`,
        `https://vidsrc.xyz/embed/tv?tmdb=${tmdbId}&season=${season}&episode=${episode}`,
        `https://embed.smashystream.com/playere.php?tmdb=${tmdbId}&season=${season}&episode=${episode}`
      );
    } else {
      candidates.push(
        // Tier 1
        `https://vidsrc.to/embed/${moviePath}`,
        `https://vidsrc.me/embed/${moviePath}`,
        `https://vsembed.ru/embed/${moviePath}/`,
        `https://player.vidsrc.co/embed/${moviePath}`,
        // Tier 2
        `https://www.2embed.cc/embed/${tmdbId}`,
        `https://multiembed.mov/?video_id=${tmdbId}&tmdb=1`,
        `https://vidsrc.xyz/embed/movie?tmdb=${tmdbId}`,
        `https://embed.smashystream.com/playere.php?tmdb=${tmdbId}`
      );
    }

    return candidates;
  }

  static async extractFromEmbed(embedUrl) {
    const debug = { embedUrl, streamsFound: 0, errors: [] };
    const browserResult = await extractWithBrowser(embedUrl);
    debug.streamsFound = browserResult.urls.length;
    if (browserResult.error) debug.errors.push(browserResult.error);
    return { urls: unique(browserResult.urls).filter(isDirectStreamUrl), debug };
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

    // Caso URL directa
    if (n.scenario === 'url') {
      const payload = {
        success:     isDirectStreamUrl(n.url),
        candidates:  isDirectStreamUrl(n.url) ? [n.url] : [],
        tmdbId:      n.tmdbId,
        type:        n.type,
        debug_info:  { source: 'direct_url' }
      };
      if (payload.success) cacheSet(cacheKey, payload);
      return payload;
    }

    // Caso TMDB → iterar candidatos
    const embeds      = this.buildCandidates(n);
    const candidates  = [];
    const debugList   = [];

    // Límite de providers a intentar (env o default 3)
    const browserLimit = Number(process.env.SCRAPER_BROWSER_LIMIT) || 3;

    for (const [i, embedUrl] of embeds.entries()) {
      // Parar si ya tenemos al menos 1 stream válido
      if (candidates.length >= 1) break;
      // Parar si superamos el límite de providers
      if (i >= browserLimit) break;

      console.log(`[scraper] Probando provider ${i + 1}/${Math.min(embeds.length, browserLimit)}: ${embedUrl}`);
      const result = await this.extractFromEmbed(embedUrl);
      debugList.push(result.debug);
      candidates.push(...result.urls);
    }

    const streamCandidates = unique(candidates).filter(isDirectStreamUrl);
    const payload = {
      success:     streamCandidates.length > 0,
      candidates:  streamCandidates,
      tmdbId:      n.tmdbId,
      type:        n.type,
      searchMode:  true,
      debug_info:  {
        embedsChecked:  debugList.length,
        streamsFound:   streamCandidates.length,
        providers:      debugList
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