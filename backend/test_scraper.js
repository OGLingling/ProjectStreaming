#!/usr/bin/env node
// test_scraper.js — Prueba el scraper con un tmdbId real
// Ejecutar: node test_scraper.js
// O probar con un ID específico: node test_scraper.js 687163 movie

require('dotenv').config();

const VideoScraper = require('./services/scraper_service');

const tmdbId  = process.argv[2] || '550';    // Fight Club por defecto
const type    = process.argv[3] || 'movie';
const season  = parseInt(process.argv[4]) || 1;
const episode = parseInt(process.argv[5]) || 1;

const label = type === 'tv' ? `TV ${tmdbId} S${season}E${episode}` : `Película ${tmdbId}`;

console.log('\n══════════════════════════════════════════════════════');
console.log(`  TEST SCRAPER — ${label}`);
console.log('══════════════════════════════════════════════════════\n');

const start = Date.now();

VideoScraper.extractStreamUrl({ tmdbId, type, season, episode })
  .then(result => {
    const elapsed = ((Date.now() - start) / 1000).toFixed(1);
    console.log('\n══════════════════════════════════════════════════════');
    console.log(`  RESULTADO (${elapsed}s)`);
    console.log('══════════════════════════════════════════════════════');
    console.log('  Success:', result.success);
    console.log('  Candidatos encontrados:', result.candidates?.length || 0);

    if (result.candidates?.length > 0) {
      console.log('\n  URLs encontradas:');
      result.candidates.forEach((url, i) => {
        const tipo = url.includes('.m3u8') ? '[HLS]' : url.includes('.mp4') ? '[MP4]' : '[?]';
        console.log(`    ${i + 1}. ${tipo} ${url.substring(0, 100)}`);
      });
    } else {
      console.log('\n  ⚠ No se encontró ningún stream');
    }

    if (result.debug_info) {
      console.log('\n  Debug info:');
      console.log('  ', JSON.stringify(result.debug_info, null, 2).replace(/\n/g, '\n  '));
    }
    console.log('══════════════════════════════════════════════════════\n');
    process.exit(result.success ? 0 : 1);
  })
  .catch(err => {
    const elapsed = ((Date.now() - start) / 1000).toFixed(1);
    console.error(`\n  ❌ ERROR FATAL (${elapsed}s):`, err.message);
    console.error(err.stack);
    process.exit(1);
  });
