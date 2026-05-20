const { chromium } = require('playwright-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
chromium.use(StealthPlugin());

(async () => {
  const url = 'https://vidsrc.to/embed/movie/157336';
  console.log(`Lanzando browser...`);
  const browser = await chromium.launch({ headless: true });
  
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    ignoreHTTPSErrors: true
  });
  
  const page = await context.newPage();
  
  page.on('console', msg => {
    console.log(`[CONSOLES] ${msg.type()}: ${msg.text()}`);
  });
  
  page.on('pageerror', err => {
    console.error(`[PAGEERROR] ${err.message}`);
  });
  
  page.on('response', response => {
    const u = response.url();
    if (u.includes('.m3u8') || u.includes('.mp4')) {
      console.log(`[RESPONSE STREAM] ${u}`);
    }
  });

  try {
    console.log(`Navegando a ${url}...`);
    const res = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    console.log(`Status de respuesta: ${res ? res.status() : 'null'}`);
    
    await page.waitForTimeout(5000);
    const bodyText = await page.innerText('body');
    console.log(`Longitud del texto del body: ${bodyText.length}`);
    console.log(`Primeros 150 caracteres: "${bodyText.substring(0, 150).replace(/\n/g, ' ')}"`);
    
    await page.screenshot({ path: 'test_multiembed_stealth.png' });
    console.log(`Captura guardada.`);
  } catch (e) {
    console.error(`Error durante la navegación:`, e.message);
  } finally {
    await browser.close();
  }
})();
