
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
    // Evitar detección simple de automatización en subframes y spoofear propiedades críticas
    try {
        Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
        Object.defineProperty(navigator, 'languages', { get: () => ['es-ES', 'es', 'en'] });
        Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3, 4, 5] });
        window.chrome = {
            runtime: {},
            loadTimes: function() {},
            csi: function() {},
            app: {}
        };
    } catch(e) {}
    
    function reportStream(url) {
        if (typeof window.onStreamFound === 'function') {
            window.onStreamFound(url);
        } else {
            // Respaldar con CustomEvent por si acaso
            window.dispatchEvent(new CustomEvent('stream_found', { detail: url }));
        }
    }

    const originalOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url) {
        if (url && (url.includes('.m3u8') || url.includes('.mp4') || url.includes('videoplayback'))) {
            reportStream(url);
        }
        return originalOpen.apply(this, arguments);
    };
    const originalFetch = window.fetch;
    window.fetch = function() {
        const url = typeof arguments[0] === 'string' ? arguments[0] : (arguments[0] && arguments[0].url);
        if (url && (url.includes('.m3u8') || url.includes('.mp4') || url.includes('videoplayback'))) {
            reportStream(url);
        }
        return originalFetch.apply(this, arguments);
    };
    // Capturar si el player usa postMessage para comunicar el link
    window.addEventListener('message', function(e) {
        if (e.data && typeof e.data === 'string' && (e.data.includes('.m3u8') || e.data.includes('.mp4'))) {
            reportStream(e.data);
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

let lastMouseX = Math.random() * 100;
let lastMouseY = Math.random() * 100;

// Generar una trayectoria de curva Bézier y deslizar el ratón con micro-retrasos reales
async function glideMouse(page, targetX, targetY) {
  try {
    const startX = lastMouseX;
    const startY = lastMouseY;

    // Puntos de control aleatorios para la curva Bézier cúbica
    const controlX1 = startX + (targetX - startX) * 0.25 + (Math.random() * 80 - 40);
    const controlY1 = startY + (targetY - startY) * 0.25 + (Math.random() * 80 - 40);
    const controlX2 = startX + (targetX - startX) * 0.75 + (Math.random() * 80 - 40);
    const controlY2 = startY + (targetY - startY) * 0.75 + (Math.random() * 80 - 40);

    const distance = Math.hypot(targetX - startX, targetY - startY);
    // Número de pasos dinámico según la distancia (mínimo 10, máximo 30)
    const steps = Math.min(30, Math.max(10, Math.round(distance / 30)));

    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      // Función smoothstep para simular aceleración y desaceleración (Ley de Fitts)
      const easeT = t * t * (3 - 2 * t);

      const x = Math.round(
        Math.pow(1 - easeT, 3) * startX +
        3 * Math.pow(1 - easeT, 2) * easeT * controlX1 +
        3 * (1 - easeT) * Math.pow(easeT, 2) * controlX2 +
        Math.pow(easeT, 3) * targetX
      );
      const y = Math.round(
        Math.pow(1 - easeT, 3) * startY +
        3 * Math.pow(1 - easeT, 2) * easeT * controlY1 +
        3 * (1 - easeT) * Math.pow(easeT, 2) * controlY2 +
        Math.pow(easeT, 3) * targetY
      );

      await page.mouse.move(x, y).catch(() => {});
      // Micro-pausa física entre pasos (8ms a 18ms)
      await page.waitForTimeout(8 + Math.random() * 10);
    }

    lastMouseX = targetX;
    lastMouseY = targetY;
  } catch (e) {
    await page.mouse.move(targetX, targetY).catch(() => {});
    lastMouseX = targetX;
    lastMouseY = targetY;
  }
}

// Simular comportamiento humano de deslizamiento del mouse antes del clic y presión sostenida
async function humanClick(page, x, y) {
  try {
    // Deslizar suavemente
    await glideMouse(page, x, y);

    // Pausa de reacción del cerebro antes del clic (100ms - 250ms)
    await page.waitForTimeout(100 + Math.random() * 150);

    // Presión física
    await page.mouse.down().catch(() => {});
    // Duración de la presión (tiempo de pulsado físico: 60ms - 120ms)
    await page.waitForTimeout(60 + Math.random() * 60);
    await page.mouse.up().catch(() => {});

    // Pausa post-clic para asimilar el cambio visual
    await page.waitForTimeout(150 + Math.random() * 150);
  } catch (e) {
    await page.mouse.click(x, y).catch(() => {});
  }
}

// ─── INTERACCIÓN CON PLAYER ──────────────────────────────────────────────────
async function interactWithPlayer(page) {
  try {
    // Comprobar si el video ya está activo y reproduciéndose
    const isAlreadyPlaying = await page.evaluate(() => {
      const v = document.querySelector('video');
      return v && !v.paused && v.readyState >= 2;
    }).catch(() => false);

    if (isAlreadyPlaying) {
      console.log('[browser] 🎥 Video ya detectado en reproducción activa. Omitiendo clics.');
      return;
    }

    const playSelectors = [
      '.jw-display-icon-container', '.vjs-big-play-button', '.plyr__control--overlaid',
      'video', 'button.play', '.play', '#play', '[class*="play" i]', '[id*="play" i]'
    ];

    // 1. Buscar elementos de play explícitos en la página principal e iframes,
    // y hacerles clic físico mediante coordenadas absolutas.
    const frames = page.frames();
    for (const frame of frames) {
      for (const selector of playSelectors) {
        try {
          const locator = frame.locator(selector);
          const count = await locator.count().catch(() => 0);
          for (let i = 0; i < count; i++) {
            const el = locator.nth(i);
            const isVisible = await el.isVisible().catch(() => false);
            if (isVisible) {
              const box = await el.boundingBox().catch(() => null);
              if (box && box.width > 12 && box.height > 12) {
                console.log(`[browser] 🎯 Botón de play prioritario en x=${Math.round(box.x + box.width/2)}, y=${Math.round(box.y + box.height/2)} (Selector: ${selector})`);
                await humanClick(page, box.x + box.width/2, box.y + box.height/2);
                await page.waitForTimeout(2000 + Math.random() * 1000);
                return; // Salir tras clic exitoso
              }
            }
          }
        } catch (_) {}
      }
    }

    // 2. Si no hay botones explícitos, clic nativo humano en el centro de la pantalla principal
    console.log('[browser] 🖱 Clic nativo en el centro de la pantalla principal');
    await humanClick(page, 640 + (Math.random() * 30 - 15), 360 + (Math.random() * 30 - 15));
    await page.waitForTimeout(1500 + Math.random() * 1000);

    // 3. Clic nativo en el centro de los iframes grandes (de forma secuencial, máx. 2)
    const iframeElements = await page.$$('iframe');
    let clickedIframeCount = 0;
    for (const iframeEl of iframeElements) {
      if (clickedIframeCount >= 2) break;
      try {
        const box = await iframeEl.boundingBox();
        if (box && box.width > 150 && box.height > 150) {
          console.log(`[browser] 🖱 Clic nativo en centro de iframe secuencial (${clickedIframeCount + 1})`);
          await humanClick(page, box.x + box.width / 2 + (Math.random() * 20 - 10), box.y + box.height / 2 + (Math.random() * 20 - 10));
          await page.waitForTimeout(2000 + Math.random() * 1000);
          clickedIframeCount++;
        }
      } catch (e) {}
    }

    // 4. Teclas globales de reproducción con intervalos naturales
    await page.keyboard.press('k').catch(() => {});
    await page.waitForTimeout(300 + Math.random() * 300);
    await page.keyboard.press('Space').catch(() => {});
    await page.waitForTimeout(1000 + Math.random() * 500);

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
            '--autoplay-policy=no-user-gesture-required',
            // Evitar que el antivirus (ESET, Avast, etc.) intercepte via extensión del navegador
            '--disable-extensions',
            '--disable-plugins',
            // Bypassear la inspección SSL del antivirus (MitM de ESET)
            '--ignore-certificate-errors',
            '--ignore-ssl-errors',
            '--ignore-certificate-errors-spki-list',
            // Estabilidad extra
            '--no-zygote',
            '--disable-background-networking'
          ]
        });
      }

      const context = await browser.newContext({
        viewport: { width: 1280, height: 720 },
        ignoreHTTPSErrors: true,
        userAgent: DESKTOP_UA,
        locale: 'es-ES',
        extraHTTPHeaders: {
          'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8,en-US;q=0.7'
        }
      });

      // Exponer la función para que el sniffer de red pueda reportar streams directamente
      await context.exposeFunction('onStreamFound', (url) => {
        if (isDirectStreamUrl(url) && !found.includes(url)) {
          console.log(`[browser sniffer] 🎯 Stream interceptado por sniffer: ${url.substring(0, 80)}`);
          found.push(url);
        }
      });

      // Registrar el script de inicialización del sniffer en la página principal y subframes
      await context.addInitScript(SNIFFER_SCRIPT);

      const page = await context.newPage();

      // Registrar logs de consola del navegador para diagnóstico
      page.on('console', msg => {
        const txt = msg.text();
        if (txt.includes('CORS') || txt.includes('Blocked') || msg.type() === 'error') {
          console.log(`[browser console] ${msg.type()}: ${txt.substring(0, 100)}`);
        }
      });
      page.on('pageerror', err => {
        console.error(`[browser pageerror] ${err.message.substring(0, 120)}`);
      });

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

      // ─── MONITOREO DE RED: REQUESTS ──────────────────────────────────────────
      page.on('request', request => {
        const u = request.url();
        if (isDirectStreamUrl(u) && !found.includes(u)) {
          console.log(`[browser] 🎯 Request: ${u.substring(0, 80)}`);
          found.push(u);
        }
      });

      // ─── MONITOREO DE RED: RESPONSE BODIES ───────────────────────────────────
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

      // Bloqueo suave de publicidad (solo aborta dominios de anuncios explícitos, no bloquea imágenes ni fuentes de maquetación)
      await page.route('**/*', (route) => {
        const url = route.request().url();
        if (isAdOrNoiseUrl(url)) {
          return route.abort().catch(() => {});
        }
        route.continue().catch(() => {});
      });

      // Navegación con timeout
      const gotoTimeout = 35000;
      console.log(`[browser] → Navegando a ${embedUrl}`);
      await page.goto(embedUrl, { waitUntil: 'domcontentloaded', timeout: gotoTimeout });

      // Esperar a que la red se calme antes de inspeccionar (importante para Cloudflare y proveedores lentos)
      await page.waitForLoadState('domcontentloaded').catch(() => {});
      await page.waitForTimeout(5000);
      await takeScreenshot('L1_Initial');

      // ─── CICLO DE INSPECCIÓN ──────────────────────────────────────────────────
      for (let layer = 1; layer <= 3; layer++) {
        if (found.length > 0) break;

        console.log(`[browser] 📂 Capa ${layer}: Analizando y activando...`);

        // Detección de errores comunes en el DOM + dentro de iframes
        let pageStatus = await page.evaluate(() => {
          const bodyText = (document.body?.innerText || '').toLowerCase();

          if (bodyText.includes('media is unavailable') || bodyText.includes('not found') ||
              bodyText.includes('removed') || bodyText.includes('no longer available') ||
              bodyText.includes('this video has been removed')) return 'unavailable';

          if (bodyText.includes('verify you are human') || bodyText.includes('cloudflare') ||
              bodyText.includes('captcha') || bodyText.includes('turnstile')) return 'blocked';

          // Buscar elementos interactivos en el documento principal e iframes accesibles
          const hasInteractiveInMain = !!document.querySelector('iframe, video, button, canvas, #player, .player, [class*="play"], [id*="play"]');
          if (hasInteractiveInMain) return 'ok';

          // Intentar inspeccionar iframes del mismo origen
          try {
            const iframes = document.querySelectorAll('iframe');
            for (const f of iframes) {
              try {
                const doc = f.contentDocument;
                if (doc && doc.querySelector('video, button, canvas, #player, .player')) return 'ok';
              } catch (_) {}
            }
          } catch (_) {}

          return 'blank';
        }).catch(() => 'error');

        // Verificación adicional vía frames de Playwright (cross-origin iframes)
        if (pageStatus === 'blank') {
          const allFrames = page.frames();
          for (const fr of allFrames) {
            if (fr === page.mainFrame()) continue;
            try {
              const hasEl = await fr.evaluate(() =>
                !!document.querySelector('video, button, canvas, #player, .player, [class*="play"], [id*="play"], iframe')
              ).catch(() => false);
              if (hasEl) {
                pageStatus = 'ok'; // Corrección real: el frame anidado tiene contenido
                console.log(`[browser] 🔍 Contenido interactivo encontrado en frame anidado → estado: ok`);
                break;
              }
            } catch (_) {}
          }
        }

        if (pageStatus === 'unavailable') {
          console.warn(`[browser] ❌ Contenido no disponible en el proveedor.`);
          await takeScreenshot(`L${layer}_Unavailable`);
          await browser.close().catch(() => {});
          return { error: 'unavailable', urls: [] };
        }

        if (pageStatus === 'blank') {
          console.warn(`[browser] ⬜ Página vacía detectada en capa ${layer}. Esperando...`);
          await takeScreenshot(`L${layer}_Blank`);
          await page.waitForTimeout(3000);
        }

        if (pageStatus === 'blocked') {
          console.warn(`[browser] 🛡️ Bloqueo/Captcha detectado.`);
          await takeScreenshot(`L${layer}_Blocked`);
          if (attempt < 3) break;
        }

        await interactWithPlayer(page);
        await page.waitForTimeout(5000);
        await takeScreenshot(`L${layer}_AfterInteract`);

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
  static clearCache(source) {
    try {
      const n = this.normalizeRequest(source);
      if (n.scenario === 'invalid') return;
      
      const cacheKey = n.scenario === 'url'
        ? `stream-url-${n.url}`
        : `stream-${n.type}-${n.tmdbId}-${n.season}-${n.episode}`;
        
      if (cache.has(cacheKey)) {
        cache.delete(cacheKey);
        console.log(`[scraper] 🧹 Cache del scraper limpiado para la clave: ${cacheKey}`);
      }
    } catch (e) {
      console.error(`[scraper] Error al intentar limpiar el caché: ${e.message}`);
    }
  }

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