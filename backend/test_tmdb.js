const TMDBCrawler = require('./services/tmdb_crawler');

async function test() {
  console.log('══════════════════════════════════════════════════════');
  console.log('  TEST TMDB CRAWLER — Interstellar (157336)');
  console.log('══════════════════════════════════════════════════════\n');

  const result = await TMDBCrawler.getMetadata('157336', 'movie');

  if (result.success) {
    console.log('✅ Metadata extraída con éxito:');
    console.log('------------------------------------------------------');
    console.log(`🎬 Título:      ${result.data.title}`);
    console.log(`📅 Lanzamiento: ${result.data.releaseDate}`);
    console.log(`⭐ Calificación: ${result.data.rating}`);
    console.log(`🎭 Géneros:     ${result.data.genres}`);
    console.log(`🖼 Póster:      ${result.data.imageUrl}`);
    console.log(`📝 Descripción: ${result.data.description?.substring(0, 150)}...`);
    console.log('------------------------------------------------------');
  } else {
    console.error('❌ Error:', result.error);
  }
}

test();
