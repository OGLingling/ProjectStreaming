require('dotenv').config();
const TMDBApi = require('./services/tmdb_api_service');

async function test() {
  console.log('══════════════════════════════════════════════════════');
  console.log('  TEST TMDB API — Interstellar (157336)');
  console.log('══════════════════════════════════════════════════════\n');

  const result = await TMDBApi.getFullMetadata('157336', 'movie');

  if (result.success) {
    const d = result.data;
    console.log('✅ Datos obtenidos de la API oficial:');
    console.log('------------------------------------------------------');
    console.log(`🎬 Título:      ${d.title}`);
    console.log(`⭐ Puntuación:  ${d.rating}/10`);
    console.log(`🎭 Géneros:     ${d.category}`);
    console.log(`📺 Tráiler:     ${d.trailerUrl}`);
    console.log(`👥 Reparto:     ${d.cast.map(a => a.name).join(', ')}`);
    console.log(`📝 Sinopsis:    ${d.description.substring(0, 200)}...`);
    console.log('------------------------------------------------------');
  } else {
    console.error('❌ Error:', result.error);
    console.log('\n💡 Asegúrate de haber puesto tu TMDB_API_TOKEN en el archivo .env');
  }
}

test();
