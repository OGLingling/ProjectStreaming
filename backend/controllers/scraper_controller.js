const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');

puppeteer.use(StealthPlugin());

const STREAM_PATTERNS = ['.m3u8', '.mp4', 'master.m3u8', 'index.m3u8', '/stream/', '/videoplayback'];

const isStreamUrl = (rawUrl) => {
  const lowered = (rawUrl || '').toLowerCase();
  return STREAM_PATTERNS.some((pattern) => lowered.includes(pattern)) && !lowered.includes('audio');
};

const extractLink = async (req, res) => {
  const { url } = req.query;

  if (!url || typeof url !== 'string') {
    return res.status(400).json({
      success: false,
      error: "Falta el parámetro 'url'."
    });
  }

  let browser;

  try {
    const referer = new URL(url).origin + '/';

    browser = await puppeteer.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-dev-shm-usage'
      ]
    });

    const page = await browser.newPage();

    // Timeout máximo de 15s para fallar rápido y evitar 504
    page.setDefaultNavigationTimeout(15000);
    page.setDefaultTimeout(15000);

    await page.setExtraHTTPHeaders({
      Referer: referer,
      'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      Connection: 'keep-alive'
    });

    let detectedStream = null;

    page.on('response', (response) => {
      const responseUrl = response.url();
      if (!detectedStream && isStreamUrl(responseUrl)) {
        detectedStream = responseUrl;
      }
    });

    await page.goto(url, { waitUntil: 'domcontentloaded' });

    // Uso de page.evaluate (sin métodos obsoletos)
    await page.evaluate(() => {
      window.scrollBy(0, 250);
      const media = document.querySelector('video, iframe');
      if (media && typeof media.click === 'function') {
        media.click();
      }
    });

    await new Promise((resolve) => setTimeout(resolve, 4000));

    if (!detectedStream) {
      detectedStream = await page.evaluate(() => {
        const candidates = [];

        const video = document.querySelector('video');
        if (video?.src) candidates.push(video.src);

        document.querySelectorAll('source').forEach((source) => {
          if (source?.src) candidates.push(source.src);
        });

        document.querySelectorAll('iframe').forEach((iframe) => {
          if (iframe?.src) candidates.push(iframe.src);
        });

        const regex = /(https?:\/\/[^\s"'<>]+\.(m3u8|mp4)[^\s"'<>]*)/gi;
        document.querySelectorAll('script').forEach((script) => {
          const content = script?.textContent || '';
          const matches = content.match(regex);
          if (matches) candidates.push(...matches);
        });

        return candidates.find((item) => {
          const u = (item || '').toLowerCase();
          return (
            (u.includes('.m3u8') || u.includes('.mp4') || u.includes('master.m3u8') || u.includes('index.m3u8')) &&
            !u.includes('audio')
          );
        }) || null;
      });
    }

    if (!detectedStream) {
      throw new Error('Video no encontrado');
    }

    return res.status(200).json({
      success: true,
      streamUrl: detectedStream
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  } finally {
    // CRÍTICO: cerrar siempre navegador para no agotar RAM
    if (browser) await browser.close();
  }
};

module.exports = { extractLink };