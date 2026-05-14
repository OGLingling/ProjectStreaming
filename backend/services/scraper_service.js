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
  'doubleclick', 'googlesyndication', 'google-analytics',
  'adservice', 'adsterra', 'popads', 'propeller',
  'taboola', 'onclick', 'tracking', 'sharethis',
  'dtscout', 'crwdcntrl', 'lijit', 'pxdrop'
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
    Referer: refererUrl && isValidUrl(refererUrl) ? refererUrl : `${origin}/`,
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
    try { urls.push(new URL(match[1], baseUrl).toString()); } catch (_) { }
  }

  return unique(urls.map((url) => url.replace(/[),;]+$/g, ''))).filter(isDirectStreamUrl);
}

function isAdOrNoiseUrl(url) {
  const lower = String(url || '').toLowerCase();
  return AD_HOST_HINTS.some((hint) => lower.includes(hint));
}

// ─── WAIT HELPER ─────────────────────────────────────────────────────────────
// Espera hasta encontrar una stream URL o hasta que se acabe el tiempo.
// Más confiable que un waitForTimeout fijo.
async function waitForStreamOrTimeout(found, maxMs = 15000, checkIntervalMs = 500) {
  const deadline = Date.now() + maxMs;
  while (Date.now() < deadline) {
    if (found.some(isDirectStreamUrl)) return true;
    await new Promise(r => setTimeout(r, checkIntervalMs));
  }
  return found.some(isDirectStreamUrl);
}

// ---------------- BROWSER (PLAYWRIGHT) ----------------
async function extractWithBrowser(embedUrl) {
  const found = [];
  let browser;

  try {
    const { chromium } = require('playwright');

    browser = await chromium.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-web-security',
        '--autoplay-policy=no-user-gesture-required',
        '--disable-features=IsolateOrigins,site-per-process'
      ]
    });

    const context = await browser.newContext({
      userAgent: MOBILE_USER_AGENT,
      viewport: { width: 412, height: 915 },
      isMobile: true,
      hasTouch: true
    });

    // ── Función reutilizable para scrapear una página ─────────────────────
    // FIX #1: referer se propaga correctamente como header HTTP, no solo como
    // extraHTTPHeaders del contexto (que a veces no se aplica en navegaciones).
    async function scrapePage(url, refererUrl = null) {
      const page = await context.newPage();

      // FIX #2: el referer exacto es crítico para player.vidsrc.co y vsembed.ru.
      // Si viene de vsembed.ru, el Origin debe ser vsembed.ru, no vidsrc.to.
      const effectiveReferer = refererUrl || `${new URL(url).origin}/`;
      const effectiveOrigin = isValidUrl(refererUrl)
        ? new URL(refererUrl).origin
        : new URL(url).origin;

      await page.setExtraHTTPHeaders({
        'User-Agent': MOBILE_USER_AGENT,
        'Referer': effectiveReferer,
        'Origin': effectiveOrigin,
        'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8'
      });

      // FIX #3: interceptar ANTES de navegar, incluir XHR y Fetch, no solo "document".
      await page.route('**/*', async (route) => {
        const reqUrl = route.request().url();
        const resType = route.request().resourceType();

        if (isDirectStreamUrl(reqUrl) && !isAdOrNoiseUrl(reqUrl)) {
          found.push(reqUrl);
          console.log(`[browser] ✅ Stream capturado (route): ${reqUrl.substring(0, 80)}`);
        }

        // Bloquear ruido que solo consume ancho de banda
        if (resType === 'font' || resType === 'image' || isAdOrNoiseUrl(reqUrl)) {
          return route.abort();
        }
        return route.continue();
      });

      page.on('request', (request) => {
        const reqUrl = request.url();
        if (isDirectStreamUrl(reqUrl) && !isAdOrNoiseUrl(reqUrl)) {
          found.push(reqUrl);
          console.log(`[browser] ✅ Stream capturado (event): ${reqUrl.substring(0, 80)}`);
        }
      });

      // FIX #4: usar 'domcontentloaded' en lugar de 'networkidle'.
      // Los players de vidsrc tienen polling continuo → networkidle NUNCA llega,
      // el timeout corta la ejecución antes de que el m3u8 se solicite.
      try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
      } catch (e) {
        if (!e.message.toLowerCase().includes('timeout')) {
          await page.close().catch(() => { });
          throw e;
        }
        console.log(`[browser] goto timeout (ignorado): ${url}`);
      }

      // FIX #5: esperar que el player exista en el DOM antes de clickear.
      // El click ciego en querySelector falla si el player aún no renderizó.
      try {
        await page.waitForSelector('video, [class*="play"], .jw-display, .plyr__control', {
          timeout: 5000
        });
      } catch (_) {
        // El selector no apareció — intentar click genérico igual
      }

      await page.evaluate(() => {
        const selectors = [
          'video',
          '.jw-display-icon-container',
          '.plyr__control--overlaid',
          '[class*="play"]',
          '[role="button"]',
          'button',
          '.play',
          '#play'
        ];
        for (const sel of selectors) {
          const el = document.querySelector(sel);
          if (el) { el.click(); return; }
        }
      }).catch(() => { });

      // FIX #6: espera adaptativa — no esperar tiempo fijo, sino hasta detectar
      // el stream o hasta que pasen 15s. Si ya hay stream, termina antes.
      await waitForStreamOrTimeout(found, 15000);

      // Si aún no hay stream, un segundo click puede ser necesario
      // (algunos players requieren dos interacciones para iniciar)
      if (!found.some(isDirectStreamUrl)) {
        await page.evaluate(() => {
          const el = document.querySelector('video, [class*="play"], button');
          if (el) el.click();
        }).catch(() => { });
        await waitForStreamOrTimeout(found, 8000);
      }

      // Extraer iframes para la siguiente capa
      const iframes = await page.evaluate(() =>
        [...document.querySelectorAll('iframe')]
          .map(f => f.src)
          .filter(s => s && s.startsWith('http'))
      ).catch(() => []);

      await page.close();

      // FIX #7: ampliar la lista de noise a filtrar al extraer iframes.
      const IFRAME_NOISE = [
        'google', 'ads', 'sharethis', 'dtscout',
        'crwdcntrl', 'lijit', 'pxdrop', 'facebook',
        'twitter', 'analytics'
      ];
      return iframes.filter(u => !IFRAME_NOISE.some(n => u.includes(n)));
    }

    // ── Paso 1: scrape de la URL de entrada ──────────────────────────────
    console.log(`[browser] Iniciando: ${embedUrl}`);
    const level1Iframes = await scrapePage(embedUrl, null);
    console.log(`[browser] Iframes L1:`, level1Iframes);

    // ── Paso 2: seguir iframes si no hay stream aún ──────────────────────
    if (!found.some(isDirectStreamUrl) && level1Iframes.length > 0) {
      // Priorizar los proveedores conocidos
      const PRIORITY_HOSTS = ['vsembed', 'cloudnestra', 'vidsrc', 'embedrise'];
      const sorted = [...level1Iframes].sort((a, b) => {
        const aScore = PRIORITY_HOSTS.findIndex(h => a.includes(h));
        const bScore = PRIORITY_HOSTS.findIndex(h => b.includes(h));
        return (aScore === -1 ? 99 : aScore) - (bScore === -1 ? 99 : bScore);
      });

      for (const iframeUrl of sorted.slice(0, 3)) {
        if (found.some(isDirectStreamUrl)) break;
        console.log(`[browser] → L2 iframe: ${iframeUrl}`);
        try {
          const level2Iframes = await scrapePage(iframeUrl, embedUrl);
          console.log(`[browser] Iframes L2 desde ${iframeUrl}:`, level2Iframes);

          // ── Paso 3: tercer nivel si hace falta ──────────────────────
          // FIX #8: el problema original es exactamente aquí.
          // vidsrc.me → vsembed.ru → player.vidsrc.co (era nivel 3, no explorado)
          if (!found.some(isDirectStreamUrl) && level2Iframes.length > 0) {
            for (const deepUrl of level2Iframes.slice(0, 2)) {
              if (found.some(isDirectStreamUrl)) break;
              console.log(`[browser] → L3 iframe: ${deepUrl}`);
              try {
                await scrapePage(deepUrl, iframeUrl);
              } catch (e) {
                console.log(`[browser] L3 falló: ${e.message}`);
              }
            }
          }
        } catch (e) {
          console.log(`[browser] L2 falló: ${e.message}`);
        }
      }
    }

    // ── Fallback: extracción del HTML renderizado ────────────────────────
    if (!found.some(isDirectStreamUrl)) {
      console.log(`[browser] Fallback: extrayendo del HTML estático`);
      const page = await context.newPage();
      await page.goto(embedUrl, { waitUntil: 'domcontentloaded', timeout: 10000 }).catch(() => { });
      const content = await page.content().catch(() => '');
      found.push(...extractDirectUrlsFromText(content, embedUrl));
      await page.close();
    }

    await context.close();

  } catch (error) {
    console.error(`[browser] Error crítico en ${embedUrl}: ${error.message}`);
    return { urls: unique(found).filter(isDirectStreamUrl), error: error.message };
  } finally {
    if (browser) await browser.close().catch(() => { });
  }

  const result = unique(found).filter(isDirectStreamUrl);
  console.log(`[browser] Total streams encontrados: ${result.length}`);
  return { urls: result, error: null };
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

    // FIX #9: agregar vsembed.ru como candidato directo ya que es el player real.
    // Saltarse la capa intermedia de vidsrc.me reduce un nivel de indirección.
    const candidates = [
      `https://vidsrc.to/embed/${path}`,
      `https://vidsrc.me/embed/${path}`,
      `https://vsembed.ru/embed/${path}/`,
      isTV
        ? `https://www.2embed.cc/embedtv/${tmdbId}&s=${season}&e=${episode}`
        : `https://www.2embed.cc/embed/${tmdbId}`,
      `https://player.vidsrc.co/embed/${path}`
    ];

    return candidates;
  }

  static async extractFromEmbed(embedUrl, options = {}) {
    const useBrowser = options.useBrowser !== false;
    const debug = { embedUrl, browserCount: 0, errors: [] };
    const urls = [];

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

    const browserLimit = Number(process.env.SCRAPER_BROWSER_LIMIT) || 3;

    for (const [index, embedUrl] of embeds.entries()) {
      if (candidates.length >= 2) break;
      const result = await this.extractFromEmbed(embedUrl, {
        useBrowser: index < browserLimit
      });
      debug.push(result.debug);
      candidates.push(...result.urls);
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

    if (payload.success) cacheSet(cacheKey, payload);
    return payload;
  }

  static async extractStreamUrl(source) {
    return await this.createPayload(source);
  }
}

module.exports = VideoScraper;