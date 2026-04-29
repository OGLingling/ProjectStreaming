const fs = require('fs');
const { chromium } = require('playwright');

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

    const launchOptions = {
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--no-first-run',
        '--no-zygote',
        '--single-process'
      ]
    };

    const chromePath = process.env.CHROME_PATH || '/usr/bin/google-chrome';
    if (fs.existsSync(chromePath)) {
      launchOptions.executablePath = chromePath;
    }

    browser = await chromium.launch(launchOptions);

    const context = await browser.newContext({
      userAgent:
        'Mozilla/5.0 (Linux; Android 13; Pixel 7 Pro Build/TQ3A.230901.001; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/124.0.6367.179 Mobile Safari/537.36 MovieWind/1.0',
      extraHTTPHeaders: {
        Referer: referer,
        'X-Client-Platform': 'mobile-app'
      }
    });

    const page = await context.newPage();
    page.setDefaultNavigationTimeout(20000);
    page.setDefaultTimeout(20000);

    let detectedStream = null;

    page.on('response', async (response) => {
      const responseUrl = response.url();
      if (!detectedStream && isStreamUrl(responseUrl)) {
        detectedStream = responseUrl;
      }
    });

    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });

    // Uso de page.evaluate (sin métodos obsoletos)
    await page.evaluate(() => {
      window.scrollBy(0, 250);
      const media = document.querySelector('video, iframe');
      if (media && typeof media.click === 'function') {
        media.click();
      }
    });

    await new Promise((resolve) => setTimeout(resolve, 3000));

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
      await Promise.race([
        page.waitForResponse((response) => isStreamUrl(response.url()), { timeout: 20000 })
          .then((response) => {
            detectedStream = response.url();
          }),
        new Promise((resolve) => setTimeout(resolve, 20000))
      ]);
    }

    if (!detectedStream) throw new Error('Video no encontrado');

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
    // OBLIGATORIO: cerrar siempre browser para evitar fuga de RAM en Railway
    if (browser) await browser.close();
  }
};

module.exports = { extractLink };
