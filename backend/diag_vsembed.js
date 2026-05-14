// diag_vsembed.js — diagnóstico directo de vsembed.ru
require('dotenv').config();

let chromium;
try {
  const pe = require('playwright-extra');
  const sp = require('puppeteer-extra-plugin-stealth');
  chromium = pe.chromium;
  chromium.use(sp());
  console.log('[diag] stealth activado');
} catch (e) {
  chromium = require('playwright').chromium;
  console.log('[diag] stealth no disponible');
}

const TARGET = process.argv[2] || 'https://vsembed.ru/embed/movie/550/';
const REFERER = process.argv[3] || 'https://vidsrc.to/';

(async () => {
  const browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage',
      '--autoplay-policy=no-user-gesture-required',
      '--disable-blink-features=AutomationControlled'
    ]
  });

  const ctx = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    viewport: { width: 1280, height: 720 },
    ignoreHTTPSErrors: true
  });

  await ctx.addInitScript(() => {
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    window.chrome = { runtime: {} };
  });

  const page = await ctx.newPage();
  const streamFound = [];
  const allReqs = [];

  // Capturar TODAS las requests
  page.on('request', req => {
    const u = req.url();
    allReqs.push({ url: u, type: req.resourceType() });
    if (u.includes('.m3u8') || u.includes('.mp4')) {
      console.log('[diag] ✅ STREAM REQUEST:', u);
      streamFound.push(u);
    }
  });

  // Capturar responses con cuerpos JSON/JS
  page.on('response', async res => {
    try {
      const u   = res.url();
      const ct  = res.headers()['content-type'] || '';
      if (u.includes('.m3u8') || u.includes('.mp4')) {
        console.log('[diag] ✅ STREAM RESPONSE URL:', u);
        streamFound.push(u);
      }
      const isText = ct.includes('json') || ct.includes('javascript') || ct.includes('text/plain');
      const skip   = ['cloudflare', 'google', 'histats', 'dtscout', 'rtmark', 'b7510'].some(h => u.includes(h));
      if (isText && !skip) {
        const body = await res.text().catch(() => '');
        if (body.includes('.m3u8') || body.includes('.mp4')) {
          console.log('[diag] ✅ STREAM EN BODY DE:', u.substring(0, 120));
          // Extraer URLs del cuerpo
          const matches = body.match(/https?:\/\/[^\s"'<>\\]+\.m3u8[^\s"'<>\\]*/gi) || [];
          const mp4s    = body.match(/https?:\/\/[^\s"'<>\\]+\.mp4[^\s"'<>\\]*/gi) || [];
          [...matches, ...mp4s].forEach(m => {
            console.log('  → ', m.substring(0, 120));
            streamFound.push(m);
          });
        }
      }
    } catch (_) {}
  });

  await page.setExtraHTTPHeaders({ Referer: REFERER, Origin: new URL(REFERER).origin });

  console.log(`[diag] Navegando a: ${TARGET}`);
  try {
    await page.goto(TARGET, { waitUntil: 'domcontentloaded', timeout: 30000 });
  } catch (e) {
    console.log('[diag] goto err:', e.message.substring(0, 100));
  }

  console.log('[diag] Esperando 20s para Cloudflare + player...');
  await page.waitForTimeout(20000);

  // Interactuar
  try {
    await page.mouse.click(640, 360);
    await page.keyboard.press('Space');
  } catch (_) {}

  await page.waitForTimeout(8000);

  const title   = await page.title().catch(() => '?');
  const iframes = await page.evaluate(() =>
    [...document.querySelectorAll('iframe')].map(f => f.src)
  ).catch(() => []);

  const videoInfo = await page.evaluate(() => {
    const v = document.querySelector('video');
    if (!v) return null;
    return { src: v.src, currentSrc: v.currentSrc };
  }).catch(() => null);

  const htmlSnippet = (await page.content().catch(() => '')).substring(0, 1000);

  console.log('\n══════════ RESULTADO ══════════');
  console.log('Title:', title);
  console.log('Iframes:', iframes);
  console.log('Video element:', videoInfo);
  console.log('Streams encontrados:', streamFound);
  console.log('\nRequests por tipo:');
  const byType = {};
  allReqs.forEach(r => { byType[r.type] = (byType[r.type] || 0) + 1; });
  console.log(JSON.stringify(byType, null, 2));
  console.log('\nHTML snippet:', htmlSnippet.substring(0, 400));
  console.log('══════════════════════════════');

  await browser.close();
})().catch(e => console.error('[diag] FATAL:', e.message));
