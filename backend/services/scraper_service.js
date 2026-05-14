const axios = require('axios');

// ---------------- CACHE LRU ----------------
const CACHE_MAX_SIZE = 200;
const CACHE_TTL_MS = 12 * 60 * 1000;
const cache = new Map();

function cacheSet(key, value) {
  if (cache.has(key)) cache.delete(key);
  cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
  if (cache.size > CACHE_MAX_SIZE) {
    const oldestKey = cache.keys().next().value;
    cache.delete(oldestKey);
  }
}

function cacheGet(key) {
  if (!cache.has(key)) return null;
  const entry = cache.get(key);
  if (!entry || entry.expiresAt <= Date.now()) {
    cache.delete(key);
    return null;
  }
  cache.delete(key);
  cache.set(key, entry);
  return entry.value;
}

// ---------------- UTILS ----------------
const INVALID_STRINGS = new Set(['null', 'undefined', 'none', 'nan', '']);
const MOBILE_USER_AGENT =
  'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

const AD_HOST_HINTS = [
  'doubleclick',
  'googlesyndication',
  'google-analytics',
  'adservice',
  'adsterra',
  'popads',
  'propeller',
  'taboola',
  'onclick',
  'tracking'
];

const sanitize = (v) => {
  if (v === undefined || v === null) return undefined;
  const s = String(v).trim();
  return INVALID_STRINGS.has(s.toLowerCase()) ? undefined : s;
};

const isValidUrl = (s) => /^https?:\/\//i.test(String(s || ''));
const isNumericId = (s) => /^\d+$/.test(String(s || ''));

const isDirectStreamUrl = (url) => {
  const lower = String(url || '').toLowerCase();
  return (
    lower.includes('.m3u8') ||
    lower.includes('.mp4') ||
    lower.includes('googlevideo.com/videoplayback')
  );
};

const unique = (items) => [...new Set(items.filter(Boolean))];

function buildHeaders(targetUrl, refererUrl) {
  const origin =
    refererUrl && isValidUrl(refererUrl)
      ? new URL(refererUrl).origin
      : new URL(targetUrl).origin;

  return {
    'User-Agent': MOBILE_USER_AGENT,
    Referer: `${origin}/`,
    Origin: origin,
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7'
  };
}

function decodeEscapedText(value) {
  return String(value || '')
    .replace(/\\u002F/g, '/')
    .replace(/\\\//g, '/')
    .replace(/&amp;/g, '&')
    .replace(/%3A/gi, ':')
    .replace(/%2F/gi, '/')
    .replace(/%3F/gi, '?')
    .replace(/%3D/gi, '=')
    .replace(/%26/gi, '&');
}

function extractDirectUrlsFromText(text, baseUrl) {
  const decoded = decodeEscapedText(text);
  const urls = [];
  const absoluteUrlPattern =
    /https?:\/\/[^\s"'<>\\]+?(?:\.m3u8|\.mp4|videoplayback)[^\s"'<>\\]*/gi;
  const relativeUrlPattern =
    /(?:src|file|url|source)\s*[:=]\s*["']([^"']+?(?:\.m3u8|\.mp4)[^"']*)["']/gi;

  for (const match of decoded.matchAll(absoluteUrlPattern)) {
    urls.push(match[0]);
  }

  for (const match of decoded.matchAll(relativeUrlPattern)) {
    try {
      urls.push(new URL(match[1], baseUrl).toString());
    } catch (_) {
      // ignore malformed relative candidates
    }
  }

  return unique(urls.map((url) => url.replace(/[),;]+$/g, ''))).filter(isDirectStreamUrl);
}

function isAdOrNoiseUrl(url) {
  const lower = String(url || '').toLowerCase();
  return AD_HOST_HINTS.some((hint) => lower.includes(hint));
}

// ---------------- BROWSER (PLAYWRIGHT) ----------------
// Se elimina getBrowserStack() y todo rastro de Puppeteer.
// Playwright es el que está instalado en la imagen Docker y el que debe usarse.

async function extractWithBrowser(embedUrl) {
  const found = [];
  let browser;

  try {
    // Playwright está disponible en la imagen mcr.microsoft.com/playwright
    const { chromium } = require('playwright');

    browser = await chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-web-security',         // necesario para iframes cross-origin
        '--autoplay-policy=no-user-gesture-required',
        '--disable-features=IsolateOrigins,site-per-process'
      ]
    });

    const context = await browser.newContext({
      userAgent: MOBILE_USER_AGENT,
      viewport: { width: 412, height: 915 },
      isMobile: true,
      hasTouch: true,
      extraHTTPHeaders: buildHeaders(embedUrl)
    });

    const page = await context.newPage();

    // Intercepta TODAS las requests (incluyendo iframes anidados)
    // Playwright intercepta iframes automáticamente, a diferencia de Puppeteer
    await page.route('**/*', async (route) => {
      const url = route.request().url();
      const resourceType = route.request().resourceType();

      if (isDirectStreamUrl(url) && !isAdOrNoiseUrl(url)) {
        found.push(url);
      }

      // Bloquea solo lo que definitivamente no aporta nada
      if (resourceType === 'font' || isAdOrNoiseUrl(url)) {
        await route.abort();
        return;
      }

      // Deja pasar todo lo demás (especialmente 'xhr', 'fetch', 'media', 'document')
      await route.continue();
    });

    // Listener adicional en requests para capturar lo que route() puede perder
    page.on('request', (request) => {
      const url = request.url();
      if (isDirectStreamUrl(url) && !isAdOrNoiseUrl(url)) {
        found.push(url);
      }
    });

    // networkidle: espera hasta que no haya peticiones de red activas por 500ms
    // Esto garantiza que los iframes de segundo y tercer nivel también hayan cargado
    // Es más lento que domcontentloaded pero es la única forma correcta para vidsrc
    try {
      await page.goto(embedUrl, { waitUntil: 'networkidle', timeout: 28000 });
    } catch (navError) {
      // timeout de networkidle NO es fatal — el player puede haber cargado igual
      // Solo relanzamos si es un error real de navegación
      if (!navError.message.toLowerCase().includes('timeout')) {
        throw navError;
      }
    }

    // Intenta hacer click en el player para activar la carga del stream
    await page.evaluate(() => {
      const selectors = [
        'video',
        '[class*="play-btn"]',
        '[class*="jw-icon-display"]',
        '[class*="plyr__control"]',
        'button[class*="play"]',
        '[role="button"]',
        '.play',
        '#play',
        'button'
      ];
      for (const sel of selectors) {
        const el = document.querySelector(sel);
        if (el) {
          el.click();
          return;
        }
      }
    }).catch(() => {});

    // Espera real post-click para que el XHR del player resuelva el .m3u8
    // 6 segundos es el tiempo mínimo probado para vidsrc.me con iframes anidados
    await page.waitForTimeout(6000);

    // Último recurso si todavía no encontramos nada:
    // busca en el HTML renderizado (cubre variantes con URL en variable JS)
    if (!found.some(isDirectStreamUrl)) {
      const content = await page.content().catch(() => '');
      const htmlUrls = extractDirectUrlsFromText(content, embedUrl);
      found.push(...htmlUrls);

      // Log de iframes para debug — útil para entender la cadena de redirección
      const iframeSrcs = await page
        .evaluate(() =>
          [...document.querySelectorAll('iframe')]
            .map((f) => f.src)
            .filter((s) => s && s.startsWith('http'))
        )
        .catch(() => []);

      if (iframeSrcs.length > 0) {
        console.log(`[browser] Iframes en ${embedUrl}:`, iframeSrcs);
      }
    }

    await context.close();
  } catch (error) {
    console.error(`[browser] Error en ${embedUrl}: ${error.message}`);
    return { urls: unique(found).filter(isDirectStreamUrl), error: error.message };
  } finally {
    if (browser) await browser.close().catch(() => {});
  }

  return { urls: unique(found).filter(isDirectStreamUrl), error: null };
}

// ---------------- CLASS ----------------
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
      return { scenario: 'url', searchMode: false, url, tmdbId, type, isTV, season, episode };
    }
    if (tmdbId && isNumericId(tmdbId)) {
      return { scenario: 'tmdb', searchMode: true, url: null, tmdbId, type, isTV, season, episode };
    }
    return { scenario: 'invalid' };
  }

  static buildCandidates(n) {
    const { tmdbId, isTV, season, episode } = n;
    const path = isTV ? `tv/${tmdbId}/${season}/${episode}` : `movie/${tmdbId}`;

    return [
      `https://vidsrc.me/embed/${path}`,
      `https://vidsrc.to/embed/${path}`,
      `https://vidsrc.xyz/embed/${path}`,
      `https://vidsrc.win/embed/${path}`,
      `https://player.vidsrc.co/embed/${path}`,
      isTV
        ? `https://www.2embed.cc/embedtv/${tmdbId}&s=${season}&e=${episode}`
        : `https://www.2embed.cc/embed/${tmdbId}`
    ];
  }

  static async extractFromEmbed(embedUrl, options = {}) {
    const useBrowser = options.useBrowser !== false;
    const debug = { embedUrl, browserCount: 0, errors: [] };
    const urls = [];

    // ELIMINADO: el fetch estático previo era trabajo inútil.
    // Ninguno de los providers (vidsrc, 2embed) tiene el .m3u8 en el HTML estático.
    // Todos lo generan mediante JavaScript dentro de iframes anidados.
    // Hacer un fetch estático primero solo agrega latencia sin resultado.

    if (useBrowser) {
      const browserResult = await extractWithBrowser(embedUrl);
      debug.browserCount = browserResult.urls.length;
      if (browserResult.error) debug.errors.push(`browser:${browserResult.error}`);
      urls.push(...browserResult.urls);
    }

    return { urls: unique(urls).filter(isDirectStreamUrl), debug };
  }

  static async createPayload(source) {
    const n = this.normalizeRequest(source);

    if (n.scenario === 'invalid') {
      return { success: false, candidates: [], debug_info: { reason: 'invalid_params' } };
    }

    const cacheKey =
      n.scenario === 'url'
        ? `stream-url-${n.url}`
        : `stream-${n.type}-${n.tmdbId}-${n.season}-${n.episode}`;

    const cached = cacheGet(cacheKey);
    if (cached) return cached;

    if (n.scenario === 'url') {
      const payload = {
        success: isDirectStreamUrl(n.url),
        candidates: isDirectStreamUrl(n.url) ? [n.url] : [],
        tmdbId: n.tmdbId,
        type: n.type,
        searchMode: false,
        clientSideCheck: false,
        debug_info: { source: 'direct_url' }
      };
      if (payload.success) cacheSet(cacheKey, payload);
      return payload;
    }

    const embeds = this.buildCandidates(n);
    const candidates = [];
    const debug = [];

    // SCRAPER_BROWSER_LIMIT controla cuántos providers intentamos con browser
    // Default 3: suficiente para tener redundancia sin consumir demasiada RAM
    const browserLimit = Number(process.env.SCRAPER_BROWSER_LIMIT) || 3;

    for (const [index, embedUrl] of embeds.entries()) {
      const result = await this.extractFromEmbed(embedUrl, {
        useBrowser: index < browserLimit
      });
      debug.push(result.debug);
      candidates.push(...result.urls);

      // Con 2 streams encontrados es suficiente para dar opciones al usuario
      if (candidates.length >= 2) break;
    }

    const streamCandidates = unique(candidates).filter(isDirectStreamUrl);
    const payload = {
      success: streamCandidates.length > 0,
      candidates: streamCandidates,
      tmdbId: n.tmdbId,
      type: n.type,
      searchMode: true,
      clientSideCheck: false,
      debug_info: {
        embedsChecked: debug.length,
        streamsFound: streamCandidates.length,
        providers: debug
      }
    };

    // Solo cachear si encontramos algo — no tiene sentido cachear fallos
    if (payload.success) cacheSet(cacheKey, payload);
    return payload;
  }

  static async extractStreamUrl(source) {
    return await this.createPayload(source);
  }
}

module.exports = VideoScraper;
