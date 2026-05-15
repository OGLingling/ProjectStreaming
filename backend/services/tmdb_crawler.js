const path = require('path');
const fs = require('fs');

// Intentar cargar sigilo (igual que en scraper_service)
let chromium;
try {
  const playwrightExtra = require('playwright-extra');
  const StealthPlugin = require('puppeteer-extra-plugin-stealth');
  chromium = playwrightExtra.chromium;
  chromium.use(StealthPlugin());
} catch (e) {
  chromium = require('playwright').chromium;
}

class TMDBCrawler {
  constructor() {
    this.baseUrl = 'https://www.themoviedatabase.org';
    this.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  }

  async getMetadata(tmdbId, type = 'movie') {
    // Modo local (mejor reputación de IP)
    const browser = await chromium.launch({ 
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-blink-features=AutomationControlled']
    });

    const context = await browser.newContext({ 
      userAgent: this.userAgent,
      viewport: { width: 1280, height: 720 }
    });

    const page = await context.newPage();
    const url = `${this.baseUrl}/${type}/${tmdbId}?language=es-ES`;
    
    console.log(`[tmdb-crawler] 🔍 Navegando a: ${url}`);

    try {
      // TMDB a veces bloquea si vas muy rápido, simulamos espera humana
      await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });

      // Verificamos si hay bloqueo de Cloudflare
      const content = await page.content();
      if (content.includes('Cloudflare') || content.includes('Verify you are human')) {
        console.log('[tmdb-crawler] 🛡 Bloqueo detectado, intentando esperar...');
        await page.waitForTimeout(5000);
      }

      // Esperar al contenedor principal de información
      await page.waitForSelector('section.header', { timeout: 15000 });

      const metadata = await page.evaluate((type) => {
        const getText = (sel) => document.querySelector(sel)?.innerText?.trim();
        
        // Extraer Géneros (buscando en la cabecera)
        const genres = Array.from(document.querySelectorAll('.genres a'))
          .map(a => a.innerText.trim())
          .join(', ');

        // Extraer Rating
        const ratingVal = document.querySelector('.user_score_chart')?.getAttribute('data-percent');
        const rating = ratingVal ? parseFloat(ratingVal) / 10 : 0;

        // Extraer Poster
        const posterImg = document.querySelector('.poster .image_content img') || document.querySelector('.poster img');
        const posterPath = posterImg?.src || posterImg?.getAttribute('data-src');

        return {
          title: getText('h2 a') || getText('h2') || document.title.split(' — ')[0],
          description: getText('.overview p'),
          releaseDate: getText('.release')?.replace(/[\(\)]/g, ''),
          rating: rating,
          genres: genres,
          imageUrl: posterPath,
          type: type
        };
      }, type);

      // Limpiar URL de imagen (convertir miniatura a original)
      if (metadata.imageUrl && metadata.imageUrl.includes('t/p/')) {
        metadata.imageUrl = metadata.imageUrl.replace(/\/w\d+_and_h\d+_bestv2\//, '/original/')
                                            .replace(/\/w\d+\//, '/original/');
      }

      await browser.close();
      return { success: true, data: metadata };

    } catch (error) {
      console.error(`[tmdb-crawler] ❌ Error en crawling:`, error.message);
      
      // Tomar captura de error para diagnóstico
      const errPath = path.join(__dirname, '../screenshots/tmdb_error.png');
      await page.screenshot({ path: errPath }).catch(() => {});
      console.log(`[tmdb-crawler] 📸 Captura de error guardada en: ${errPath}`);
      
      await browser.close();
      return { success: false, error: error.message };
    }
  }
}

module.exports = new TMDBCrawler();
