const path = require('path');
require('dotenv').config();

const VideoScraper = require('./services/scraper_service');

const tmdbId = '157336';
const providers = [
  `https://embed.smashystream.com/playere.php?tmdb=${tmdbId}`,
  `https://multiembed.mov/?video_id=${tmdbId}&tmdb=1`,
  `https://vidsrc.to/embed/movie/${tmdbId}`
];

(async () => {
  console.log('--- TESTING PROVIDERS INDIVIDUALLY ---');
  for (const url of providers) {
    console.log(`\n======================================================`);
    console.log(`PROBANDO: ${url}`);
    console.log(`======================================================`);
    try {
      const start = Date.now();
      const result = await VideoScraper.extractFromEmbed(url);
      const elapsed = ((Date.now() - start) / 1000).toFixed(1);
      console.log(`Resultado (${elapsed}s):`);
      console.log(`  Success: ${result.urls.length > 0}`);
      console.log(`  URLs encontradas:`, result.urls);
      if (result.error) {
        console.log(`  Error:`, result.error);
      }
      console.log(`  Debug:`, JSON.stringify(result.debug, null, 2));
    } catch (e) {
      console.error(`Error probando provider:`, e.message);
    }
  }
})();
