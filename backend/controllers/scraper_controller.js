const { chromium, devices } = require('playwright');

const STREAM_PATTERNS = ['.m3u8', '.mp4', 'master.m3u8', 'index.m3u8', '/stream/', '/videoplayback'];

const isStreamUrl = (rawUrl) => {
  const lowered = (rawUrl || '').toLowerCase();
  return STREAM_PATTERNS.some((pattern) => lowered.includes(pattern)) && !lowered.includes('audio');
};

const extractLink = async (req, res) => {
  const { url } = req.query;

  if (!url) return res.status(400).json({ success: false, error: "URL requerida" });

  let browser;
  try {
    // Lanzamos Chromium con los flags de seguridad para Railway
  const browser = await chromium.launch({
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--single-process'
  ]
});

    // Simulamos un dispositivo móvil (iPhone 13) para evitar anuncios pesados
    const context = await browser.newContext({
      ...devices['iPhone 13'],
      locale: 'es-ES',
    });

    const page = await context.newPage();
    let detectedStream = null;

    // Escuchamos las respuestas de red en tiempo real
    page.on('response', response => {
      const respUrl = response.url();
      if (!detectedStream && isStreamUrl(respUrl)) {
        detectedStream = respUrl;
      }
    });

    // Navegación con timeout de 15s
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });

    // Pequeño scroll y click para disparar eventos de video
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(2000);

    if (!detectedStream) throw new Error('No se detectó flujo de video');

    return res.status(200).json({
      success: true,
      streamUrl: detectedStream
    });

  } catch (error) {
    console.error("Error en Scraper:", error.message);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  } finally {
    if (browser) await browser.close();
  }
};

module.exports = { extractLink };