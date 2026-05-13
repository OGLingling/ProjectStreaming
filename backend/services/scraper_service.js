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
  return lower.includes('.m3u8') ||
    lower.includes('.mp4') ||
    lower.includes('googlevideo.com/videoplayback');
};

const unique = (items) => [...new Set(items.filter(Boolean))];

function buildHeaders(targetUrl, refererUrl) {
  const origin = refererUrl && isValidUrl(refererUrl)
    ? new URL(refererUrl).origin
    : new URL(targetUrl).origin;

  return {
    'User-Agent': MOBILE_USER_AGENT,
    'Referer': `${origin}/`,
    'Origin': origin,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
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
  const absoluteUrlPattern = /https?:\/\/[^\s"'<>\\]+?(?:\.m3u8|\.mp4|videoplayback)[^\s"'<>\\]*/gi;
  const relativeUrlPattern = /(?:src|file|url|source)\s*[:=]\s*["']([^"']+?(?:\.m3u8|\.mp4)[^"']*)["']/gi;

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

async function fetchHtml(url) {
  const response = await axios.get(url, {
    headers: buildHeaders(url),
    timeout: 12000,
    maxRedirects: 5,
    responseType: 'text',
    validateStatus: (status) => status >= 200 && status < 500
  });

  if (response.status >= 400) {
    throw new Error(`HTTP ${response.status}`);
  }

  return String(response.data || '');
}

let browserStackPromise = null;

async function getBrowserStack() {
  if (browserStackPromise) return browserStackPromise;

  browserStackPromise = (async () => {
    const puppeteerExtra = require('puppeteer-extra');
    const StealthPlugin = require('puppeteer-extra-plugin-stealth');
    const puppeteer = require('puppeteer');

    puppeteerExtra.use(StealthPlugin());

    return { puppeteer: puppeteerExtra, executablePath: puppeteer.executablePath() };
  })();

  return browserStackPromise;
}

async function extractWithBrowser(embedUrl) {
  const found = [];
  let browser;

  try {
    const { puppeteer, executablePath } = await getBrowserStack();
    browser = await puppeteer.launch({
      headless: 'new',
      executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || executablePath,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--autoplay-policy=no-user-gesture-required',
        '--disable-features=IsolateOrigins,site-per-process'
      ]
    });

    const page = await browser.newPage();
    await page.setUserAgent(MOBILE_USER_AGENT);
    await page.setViewport({ width: 412, height: 915, isMobile: true, hasTouch: true });
    await page.setExtraHTTPHeaders(buildHeaders(embedUrl));
    await page.setRequestInterception(true);

    page.on('request', (request) => {
      const url = request.url();
      const type = request.resourceType();

      if (isDirectStreamUrl(url)) {
        found.push(url);
      }

      if (['image', 'font'].includes(type) || isAdOrNoiseUrl(url)) {
        request.abort().catch(() => {});
        return;
      }

      request.continue().catch(() => {});
    });

    page.on('response', async (response) => {
      const url = response.url();
      const headers = response.headers();
      const contentType = String(headers['content-type'] || '').toLowerCase();

      if (isDirectStreamUrl(url) || contentType.includes('mpegurl') || contentType.includes('video')) {
        found.push(url);
      }

      if (contentType.includes('javascript') || contentType.includes('json') || contentType.includes('text')) {
        try {
          const body = await response.text();
          found.push(...extractDirectUrlsFromText(body, url));
        } catch (_) {
          // Some responses are not readable after interception; safe to skip.
        }
      }
    });

    page.on('popup', async (popup) => {
      try {
        await popup.close();
      } catch (_) {
        // ignore popup close races
      }
    });

    await page.goto(embedUrl, { waitUntil: 'domcontentloaded', timeout: 18000 });

    for (let i = 0; i < 4; i += 1) {
      await page.evaluate(() => {
        const selectors = ['video', 'button', '[role="button"]', '.play', '#play'];
        for (const selector of selectors) {
          const element = document.querySelector(selector);
          if (element) {
            element.click();
            break;
          }
        }
      }).catch(() => {});
      await new Promise((resolve) => setTimeout(resolve, 1800));
      if (found.some(isDirectStreamUrl)) break;
    }
  } catch (error) {
    return { urls: unique(found).filter(isDirectStreamUrl), error: error.message };
  } finally {
    if (browser) {
      await browser.close().catch(() => {});
    }
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
    const debug = { embedUrl, staticCount: 0, browserCount: 0, errors: [] };
    const urls = [];

    try {
      const html = await fetchHtml(embedUrl);
      const staticUrls = extractDirectUrlsFromText(html, embedUrl);
      debug.staticCount = staticUrls.length;
      urls.push(...staticUrls);
    } catch (error) {
      debug.errors.push(`static:${error.message}`);
    }

    if (urls.length === 0 && useBrowser) {
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

    const cacheKey = n.scenario === 'url'
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
      const result = await this.extractFromEmbed(embedUrl, {
        useBrowser: index < browserLimit
      });
      debug.push(result.debug);
      candidates.push(...result.urls);
      if (candidates.length >= 3) break;
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

    cacheSet(cacheKey, payload);
    return payload;
  }

  static async extractStreamUrl(source) {
    return await this.createPayload(source);
  }
}

module.exports = VideoScraper;
