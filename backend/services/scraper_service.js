
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
  // Incluimos patrones más amplios de HLS y MP4
  return s.includes('.m3u8') || 
         s.includes('.mp4') || 
         s.includes('googlevideo.com/videoplayback') ||
         (s.includes('/hls/') && s.includes('.ts')) || // Segmentos TS a veces ayudan a encontrar el playlist
         s.includes('/playlist.m3u8') ||
         s.includes('master.m3u8') ||
         s.includes('manifest.m3u8');
};

const SNIFFER_SCRIPT = `
(function() {
    // Evitar detección simple de automatización en subframes
    try {
        Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    } catch(e) {}
    
    const originalOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url) {
        if (url.includes('.m3u8') || url.includes('.mp4') || url.includes('videoplayback')) {
            window.dispatchEvent(new CustomEvent('stream_found', { detail: url }));
        }
        return originalOpen.apply(this, arguments);
    };
    const originalFetch = window.fetch;
    window.fetch = function() {
        const url = typeof arguments[0] === 'string' ? arguments[0] : arguments[0].url;
        if (url && (url.includes('.m3u8') || url.includes('.mp4') || url.includes('videoplayback'))) {
            window.dispatchEvent(new CustomEvent('stream_found', { detail: url }));
        }
        return originalFetch.apply(this, arguments);
    };
    // Capturar si el player usa postMessage para comunicar el link
    window.addEventListener('message', function(e) {
        if (e.data && typeof e.data === 'string' && (e.data.includes('.m3u8') || e.data.includes('.mp4'))) {
            window.dispatchEvent(new CustomEvent('stream_found', { detail: e.data }));
        }
    });
})();
`;

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

// Simular comportamiento humano de deslizamiento del mouse antes del clic
async function humanClick(page, x, y) {
  try {
    // Mover a una posición inicial aleatoria
    await page.mouse.move(Math.random() * 200, Math.random() * 200).catch(() => {});
    // Deslizar con trayectoria curvada simulada (steps)
    await page.mouse.move(x / 2 + Math.random() * 50, y / 2 + Math.random() * 50, { steps: 5 }).catch(() => {});
    await page.mouse.move(x, y, { steps: 8 }).catch(() => {});
    // Pausa de reacción humana
    await page.waitForTimeout(100 + Math.random() * 150);
    // Realizar clic
    await page.mouse.click(x, y).catch(() => {});
  } catch (e) {}
}

// ─── INTERACCIÓN CON PLAYER ──────────────────────────────────────────────────
async function interactWithPlayer(page) {
  try {
    // 1. Clic nativo humano en el centro de la pantalla principal (isTrusted: true)
    await humanClick(page, 640, 360);
    console.log('[browser] 🖱 Clic nativo humano en el centro de la pantalla principal');

    // 2. Clic nativo humano en el centro de todos los iframes visibles
    const iframeElements = await page.$$('iframe');
    for (const iframeEl of iframeElements) {
      try {
        const box = await iframeEl.boundingBox();
        if (box && box.width > 100 && box.height > 100) {
          await humanClick(page, box.x + box.width / 2, box.y + box.height / 2);
          console.log(`[browser] 🖱 Clic nativo humano en centro de iframe: x=${Math.round(box.x + box.width / 2)}, y=${Math.round(box.y + box.height / 2)}`);
        }
      } catch (e) {}
    }

    // 3. Respaldo de clics programáticos (mantener compatibilidad)
    const frames = page.frames();
    console.log(`[browser] 📂 Interactuando con ${frames.length} frames...`);

    for (const frame of frames) {
      try {
        const isVisible = await frame.evaluate(() => {
          const el = document.body;
          return el && el.getBoundingClientRect().width > 0;
        }).catch(() => false);

        if (!isVisible) continue;

        // Simular clics en el centro del frame
        await frame.evaluate(() => {
          const width = window.innerWidth;
          const height = window.innerHeight;
          const points = [
            { x: width / 2, y: height / 2 },
            { x: width / 2 + 20, y: height / 2 + 20 },
            { x: width / 2 - 20, y: height / 2 - 20 }
          ];
          points.forEach(p => {
            const el = document.elementFromPoint(p.x, p.y);
            if (el) {
              el.click();
              // Eventos adicionales para engañar a scripts que detectan clics reales
              el.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, clientX: p.x, clientY: p.y }));
              el.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, clientX: p.x, clientY: p.y }));
            }
          });
        }).catch(() => { });

        // Buscar botones de Play y activarlos
        await frame.evaluate(() => {
          const playSelectors = [
            'video', 'button', 'a', '.play', '#play', '[class*="play" i]', '[id*="play" i]',
            '.jw-display-icon-container', '.vjs-big-play-button', '.plyr__control--overlaid'
          ];
          playSelectors.forEach(sel => {
            document.querySelectorAll(sel).forEach(el => {
              try {
                if (el.tagName === 'VIDEO') {
                  el.play().catch(() => { });
                } else {
                  el.click();
                }
              } catch (_) { }
            });
          });
        }).catch(() => { });

      } catch (frameError) {
        // Ignorar errores de frames individuales (CORS, etc.)
      }
    }

    // Atajos globales en la página principal
    await page.keyboard.press('k').catch(() => { });
    await page.keyboard.press('Space').catch(() => { });

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
  const scraperMode = process.env.SCRAPER_MODE || 'auto';

  const screenshotsDir = path.join(__dirname, '../screenshots');
  if (!fs.existsSync(screenshotsDir)) fs.mkdirSync(screenshotsDir, { recursive: true });

  console.log(`[browser] 🛠 Modo: ${scraperMode} | Objetivo: ${embedUrl}`);

  // Validar si hay proxies reales configurados (ignorar placeholders y GitHub IPs)
  const validProxies = PROXIES.filter(p => {
    const trimmed = p.trim();
    if (!trimmed || trimmed.includes('user:pass@') || trimmed.includes('proxy3.com')) return false;
    // GitHub Pages IPs no son proxies HTTP
    const githubIps = ['185.199.', '140.82.'];
    if (githubIps.some(ip => trimmed.startsWith(ip))) return false;
    return true;
  });

  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      if (scraperMode === 'browserless' && browserlessToken) {
        browser = await chromium.connectOverCDP({
          endpointURL: `wss://chrome.browserless.io?token=${browserlessToken}&stealth&--disable-notifications`,
          timeout: 40000
        });
      } else {
        // Solo usar proxy en intento 2 si hay proxies válidos disponibles
        const useProxy = (attempt === 2) && validProxies.length > 0;
        const proxyUrl = useProxy ? validProxies[proxyIndex++ % validProxies.length].trim() : null;
        const isHeadless = process.env.SCRAPER_HEADLESS !== 'false';

        // Si no hay proxies válidos, saltar directamente de intento 1 a 3
        if (attempt === 2 && validProxies.length === 0) {
          console.log(`[browser] ⚠ Sin proxies válidos, saltando intento 2`);
          continue;
        }

        browser = await chromium.launch({
          headless: isHeadless,
          channel: isHeadless ? undefined : 'chrome',
          proxy: proxyUrl ? { server: proxyUrl.startsWith('http') ? proxyUrl : `http://${proxyUrl}` } : undefined,
          args: [
            '--no-sandbox', '--disable-setuid-sandbox',
            '--disable-blink-features=AutomationControlled',
            '--disable-web-security',
            '--disable-features=IsolateOrigins,site-per-process',
            '--autoplay-policy=no-user-gesture-required'
          ]
        });
      }

      const targetOrigin = new URL(embedUrl).origin;
      const context = await browser.newContext({
        userAgent: DESKTOP_UA,
        viewport: { width: 1280, height: 720 },
        ignoreHTTPSErrors: true,
        extraHTTPHeaders: {
          'Referer': targetOrigin + '/',
          'Origin': targetOrigin,
          'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
          'Upgrade-Insecure-Requests': '1'
        }
      });

      // Inyección profunda de sigilo a nivel de contexto
      await context.addInitScript(() => {
        try { Object.defineProperty(navigator, 'webdriver', { get: () => undefined }); } catch (_) {}
        try { window.chrome = { runtime: {} }; } catch (_) {}
        try {
          const getParameter = WebGLRenderingContext.prototype.getParameter;
          WebGLRenderingContext.prototype.getParameter = function(parameter) {
            if (parameter === 37445) return 'Google Inc. (NVIDIA)';
            if (parameter === 37446) return 'ANGLE (NVIDIA, NVIDIA GeForce RTX 4060 Laptop GPU/Direct3D11, vs_5_0 ps_5_0)';
            return getParameter.apply(this, arguments);
          };
        } catch (_) {}
        try {
          Object.defineProperty(navigator, 'languages', { get: () => ['es-ES', 'es', 'en-US', 'en'] });
          Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3, 4, 5] });
        } catch (_) {}
        try {
          const originalQuery = navigator.permissions.query;
          navigator.permissions.query = (parameters) =>
            parameters.name === 'notifications'
              ? Promise.resolve({ state: Notification.permission })
              : originalQuery(parameters);
        } catch (_) {}
      });

      const page = await context.newPage();

      const takeScreenshot = async (name) => {
        try {
          const safeUrl = embedUrl.replace(/[^a-z0-9]/gi, '_').substring(0, 30);
          const filePath = path.join(screenshotsDir, `At${attempt}_${name}_${safeUrl}.png`);
          await page.screenshot({ path: filePath });
          console.log(`[browser] 📸 Captura: ${name}`);
        } catch (e) {
          console.warn(`[browser] ⚠️ No se pudo tomar captura: ${e.message}`);
        }
      };

      // Sniffer bridge para XHR/fetch dentro de la página
      await page.exposeFunction('onStreamFound', (url) => {
        if (isDirectStreamUrl(url) && !found.includes(url)) {
          console.log(`[browser] 💉 Sniffer XHR: ${url.substring(0, 80)}`);
          found.push(url);
        }
      });

      // ─── MONITOREO DE RED: REQUESTS ──────────────────────────────────────────
      page.on('request', request => {
        const u = request.url();
        if (isDirectStreamUrl(u) && !found.includes(u)) {
          console.log(`[browser] 🎯 Request: ${u.substring(0, 80)}`);
          found.push(u);
        }
      });

      // ─── MONITOREO DE RED: RESPONSE BODIES ───────────────────────────────────
      // Esta es la pieza clave: muchos players devuelven la URL m3u8 dentro de
      // una respuesta JSON/JS, no como una request directa al archivo.
      page.on('response', async (response) => {
        try {
          const u = response.url();
          const status = response.status();
          if (status < 200 || status >= 400) return;
          if (isAdOrNoiseUrl(u)) return;

          // Primero: la URL de respuesta misma puede ser un stream
          if (isDirectStreamUrl(u) && !found.includes(u)) {
            console.log(`[browser] 🎯 Response URL: ${u.substring(0, 80)}`);
            found.push(u);
          }

          // Segundo: leer el cuerpo para encontrar URLs embebidas
          const ct = (response.headers()['content-type'] || '').toLowerCase();
          const isTextContent = ct.includes('json') || ct.includes('javascript') ||
                                ct.includes('text/plain') || ct.includes('text/html');
          if (!isTextContent) return;

          const body = await response.text().catch(() => '');
          if (!body || body.length < 10) return;

          // Solo procesar si el cuerpo contiene algo relevante
          if (!body.includes('.m3u8') && !body.includes('.mp4') && !body.includes('videoplayback')) return;

          const matches = extractStreamUrlsFromText(body, u);
          for (const match of matches) {
            if (!found.includes(match)) {
              console.log(`[browser] 📡 Body(${u.substring(0,40)}): ${match.substring(0, 80)}`);
              found.push(match);
            }
          }
        } catch (_) {}
      });

      // Bloqueo de publicidad (sin bloquear streams)
      await page.route('**/*', (route) => {
        const url = route.request().url();
        if (isAdOrNoiseUrl(url)) return route.abort();
        const type = route.request().resourceType();
        if (['image', 'font'].includes(type) && !isDirectStreamUrl(url)) return route.abort();
        route.continue();
      });

      // Navegación con timeout
      const gotoTimeout = 35000;
      console.log(`[browser] → Navegando a ${embedUrl}`);
      await page.goto(embedUrl, { waitUntil: 'domcontentloaded', timeout: gotoTimeout });

      // Espera inicial más larga para Cloudflare y carga de scripts del player
      await page.waitForTimeout(4000);

      const setupPage = async (p) => {
        try {
          await p.addInitScript(SNIFFER_SCRIPT);
          await p.evaluate(() => {
            if (window.onStreamFound) return;
            window.addEventListener('stream_found', (e) => {
              if (typeof window.onStreamFound === 'function') {
                window.onStreamFound(e.detail);
              }
            });
          }).catch(() => {});
        } catch (_) {}
      };

      context.on('frameattached', async (frame) => {
        await setupPage(frame);
      });

      await setupPage(page);
      await takeScreenshot('L1_Initial');

      // ─── CICLO DE INSPECCIÓN ──────────────────────────────────────────────────
      for (let layer = 1; layer <= 3; layer++) {
        if (found.length > 0) break;

        console.log(`[browser] 📂 Capa ${layer}: Analizando y activando...`);

        // Detección de errores comunes en el DOM
        const pageStatus = await page.evaluate(() => {
          const bodyText = (document.body?.innerText || '').toLowerCase();
          const bodyLen = bodyText.trim().length;

          if (bodyText.includes('media is unavailable') || bodyText.includes('not found') ||
              bodyText.includes('removed') || bodyText.includes('no longer available')) return 'unavailable';
          if (bodyText.includes('blocked') || bodyText.includes('verify you are human') ||
              bodyText.includes('captcha')) return 'blocked';
          // Página en blanco o casi vacía (posible challenge sin resolver)
          if (bodyLen < 50) return 'blank';
          return 'ok';
        }).catch(() => 'error');

        if (pageStatus === 'unavailable') {
          console.warn(`[browser] ❌ Contenido no disponible en el proveedor.`);
          await takeScreenshot(`L${layer}_Unavailable`);
          await browser.close().catch(() => {});
          return { error: 'unavailable', urls: [] };
        }

        if (pageStatus === 'blank') {
          console.warn(`[browser] ⬜ Página en blanco/challenge sin resolver en capa ${layer}.`);
          await takeScreenshot(`L${layer}_Blank`);
          // Dar más tiempo y continuar — puede ser Cloudflare resolviendo
          await page.waitForTimeout(3000);
        }

        if (pageStatus === 'blocked') {
          console.warn(`[browser] 🛡️ Bloqueo/Captcha detectado.`);
          await takeScreenshot(`L${layer}_Blocked`);
          if (attempt < 3) break;
        }

        await interactWithPlayer(page);
        await page.waitForTimeout(5000); // Más tiempo para que el player haga sus llamadas XHR
        await takeScreenshot(`L${layer}_AfterInteract`);

        // Chequeo inmediato: el listener de response puede haber capturado URLs ya
        if (found.length > 0) break;

        const domUrls = await extractFromDOM(page, page.url());
        if (domUrls.length > 0) {
          found.push(...domUrls);
          break;
        }

        const frames = page.frames();
        for (const frame of frames) {
            if (frame === page.mainFrame()) continue;
            try {
              await setupPage(frame).catch(() => {});
              const frameUrls = await extractFromDOM(frame, frame.url()).catch(() => []);
              if (frameUrls.length > 0) found.push(...frameUrls);
            } catch (_) {}
        }

        if (found.length > 0) break;
        await page.waitForTimeout(2000);
      }

      await browser.close();
      if (found.length > 0) break;

    } catch (err) {
      console.error(`[browser] Intento ${attempt} fallido: ${err.message}`);
      if (browser) await browser.close().catch(() => {});
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
        // Proveedores de alta tasa de éxito primero (con interacción mejorada)
        `https://embed.smashystream.com/playere.php?tmdb=${tmdbId}&season=${season}&episode=${episode}`,
        `https://multiembed.mov/?video_id=${tmdbId}&tmdb=1&s=${season}&e=${episode}`,
        
        // Espejos VidSrc.to
        `https://vidsrc.to/embed/${tvPath}`,
        `https://vidsrc.net/embed/${tvPath}`,
        `https://vidsrc.cc/embed/${tvPath}`,
        
        // Espejos VidSrc.me / vsembed
        `https://vidsrc.me/embed/${tvPath}`,
        `https://vidsrcme.ru/embed/${tvPath}`,
        `https://vidsrcme.su/embed/${tvPath}`,
        `https://vidsrc-me.ru/embed/${tvPath}`,
        `https://vsembed.ru/embed/${tvPath}/`,
        
        // Espejos VidSrc.pro
        `https://vidsrc.pro/embed/${tvPath}`,
        
        // Otros proveedores
        `https://embedsu.cc/embed/${tvPath}`,
        `https://embed.su/embed/${tvPath}`,
        `https://www.2embed.cc/embedtv/${tmdbId}&s=${season}&e=${episode}`
      ];
    }

    return [
      // Proveedores de alta tasa de éxito primero (con interacción mejorada)
      `https://embed.smashystream.com/playere.php?tmdb=${tmdbId}`,
      `https://multiembed.mov/?video_id=${tmdbId}&tmdb=1`,
      
      // Espejos VidSrc.to
      `https://vidsrc.to/embed/${moviePath}`,
      `https://vidsrc.net/embed/${moviePath}`,
      `https://vidsrc.cc/embed/${moviePath}`,
      
      // Espejos VidSrc.me / vsembed
      `https://vidsrc.me/embed/${moviePath}`,
      `https://vidsrcme.ru/embed/${moviePath}`,
      `https://vidsrcme.su/embed/${moviePath}`,
      `https://vidsrc-me.ru/embed/${moviePath}`,
      `https://vsembed.ru/embed/${moviePath}/`,
      
      // Espejos VidSrc.pro
      `https://vidsrc.pro/embed/${moviePath}`,
      
      // Otros proveedores
      `https://embedsu.cc/embed/${moviePath}`,
      `https://embed.su/embed/${moviePath}`,
      `https://www.2embed.cc/embed/${tmdbId}`
    ];
  }

  static async extractFromEmbed(embedUrl) {
    const debug = { embedUrl, streamsFound: 0, errors: [] };
    const result = await extractWithBrowser(embedUrl);
    debug.streamsFound = result.urls.length;
    if (result.error) debug.errors.push(result.error);
    return { urls: unique(result.urls).filter(isDirectStreamUrl), error: result.error, debug };
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
      // Si un proveedor falla por "unavailable", no cuenta contra el límite de navegadores
      // para darnos más oportunidades de encontrar uno que sí funcione.
      if (i >= browserLimit && !debugList.some(d => d.errors.includes('unavailable'))) break;

      console.log(`[scraper] Provider ${i + 1}/${Math.min(embeds.length, browserLimit + 2)}: ${embedUrl}`);
      const result = await this.extractFromEmbed(embedUrl);
      debugList.push(result.debug);
      candidates.push(...result.urls);

      // Si encontramos algo, salimos
      if (candidates.length > 0) break;
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