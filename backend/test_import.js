const ContentService = require('./services/content_service');

async function test() {
  console.log('══════════════════════════════════════════════════════');
  console.log('  TEST IMPORTACIÓN REAL — TMDB -> POSTGRES');
  console.log('══════════════════════════════════════════════════════\n');

  // Intentamos importar Interstellar (157336)
  const result = await ContentService.importFromTMDB('157336', 'movie');

  if (result.success) {
    console.log('\n✨ ¡IMPORTACIÓN EXITOSA! ✨');
    console.log('------------------------------------------------------');
    console.log(`🆔 ID en DB:     ${result.data.id}`);
    console.log(`🎬 Título:        ${result.data.title}`);
    console.log(`📅 Fecha:         ${result.data.releaseDate}`);
    console.log(`⭐ Rating:        ${result.data.rating}`);
    console.log(`🖼️ Imagen:        ${result.data.imageUrl}`);
    console.log('------------------------------------------------------');
    console.log('\n💡 Ahora puedes revisar tu base de datos y verás la fila creada.');
  } else {
    console.error('\n❌ Fallo en la importación:', result.error);
  }

  process.exit();
}

test();
