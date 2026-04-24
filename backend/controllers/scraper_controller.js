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
      message: "Falta el parámetro 'url'."
    });
  }

  let browser;

  try {
    const referer = new URL(url).origin + '/';

    browser = await puppeteer.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu'
      ]
    });

    const page = await browser.newPage();
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

    await page.evaluate(() => {
      window.scrollBy(0, 250);
      const media = document.querySelector('video, iframe');
      if (media && typeof media.click === 'function') {
        media.click();
      }
    });

    await page.waitForTimeout(4000);

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
          const url = (item || '').toLowerCase();
          return (
            (url.includes('.m3u8') || url.includes('.mp4') || url.includes('master.m3u8') || url.includes('index.m3u8')) &&
            !url.includes('audio')
          );
        }) || null;
      });
    }

    if (!detectedStream) {
      return res.status(404).json({
        success: false,
        message: 'Video no encontrado'
      });
    }

    return res.status(200).json({
      success: true,
      streamUrl: detectedStream
    });
  } catch (error) {
    const timeout = (error.message || '').toLowerCase().includes('timeout');
    return res.status(timeout ? 504 : 500).json({
      success: false,
      message: timeout
        ? 'Timeout del scraper: no se encontró video dentro de 15 segundos.'
        : 'Error interno del scraper.',
      details: error.message
    });
  } finally {
    if (browser) await browser.close().catch(() => {});
  }
};

module.exports = { extractLink };
