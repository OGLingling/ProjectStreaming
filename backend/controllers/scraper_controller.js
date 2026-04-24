const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');

puppeteer.use(StealthPlugin());

const STREAM_PATTERNS = [
  '.m3u8',
  '.mp4',
  'master.m3u8',
  'index.m3u8',
  '/stream/',
  '/videoplayback'
];

const isStreamUrl = (rawUrl) => {
  const url = (rawUrl || '').toLowerCase();
  return STREAM_PATTERNS.some((pattern) => url.includes(pattern));
};

const extractLink = async (req, res) => {
  const { url } = req.query;

  if (!url || typeof url !== 'string') {
    return res.status(400).json({
      success: false,
      error: "Falta el parámetro 'url'. Ejemplo: /api/extract?url=https://proveedor.com/embed/..."
    });
  }

  let browser;
  let interactionTimer;

  try {
    const referer = new URL(url).origin + '/';
    browser = await puppeteer.launch({
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--single-process'
      ]
    });

    const page = await browser.newPage();

    await page.setExtraHTTPHeaders({
      Referer: referer,
      'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      Connection: 'keep-alive'
    });

    await page.setRequestInterception(true);

    const streamPromise = new Promise((resolve) => {
      page.on('request', (request) => {
        const requestUrl = request.url();

        if (isStreamUrl(requestUrl) && !requestUrl.toLowerCase().includes('audio')) {
          resolve(requestUrl);
        }

        const type = request.resourceType();
        const allow =
          type === 'document' ||
          type === 'media' ||
          type === 'xhr' ||
          type === 'fetch' ||
          type === 'script' ||
          type === 'websocket';

        if (allow) {
          request.continue().catch(() => {});
        } else {
          request.abort().catch(() => {});
        }
      });

      page.on('response', (response) => {
        const responseUrl = response.url();
        if (isStreamUrl(responseUrl) && !responseUrl.toLowerCase().includes('audio')) {
          resolve(responseUrl);
        }
      });
    });

    await page.goto(url, { waitUntil: 'networkidle0', timeout: 15000 });

    interactionTimer = setTimeout(async () => {
      try {
        await page.mouse.click(400, 300);
        await page.evaluate(() => {
          window.scrollBy(0, 250);
        });
      } catch (_) {
        // Interacción opcional para disparar requests de players lazy-load.
      }
    }, 2000);

    const timeoutPromise = new Promise((_, reject) =>
      setTimeout(() => reject(new Error('Timeout: No se detectó stream en 20 segundos')), 20000)
    );

    const streamUrl = await Promise.race([streamPromise, timeoutPromise]);

    return res.status(200).json({
      success: true,
      streamUrl
    });
  } catch (error) {
    const isTimeout = (error.message || '').toLowerCase().includes('timeout');
    return res.status(isTimeout ? 504 : 500).json({
      success: false,
      error: isTimeout
        ? 'Timeout del scraper: no se encontró un stream en 20 segundos.'
        : 'No se pudo extraer el enlace del video.',
      details: error.message
    });
  } finally {
    if (interactionTimer) {
      clearTimeout(interactionTimer);
    }
    if (browser) {
      await browser.close().catch(() => {});
    }
  }
};

module.exports = {
  extractLink
};
