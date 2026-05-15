const ContentService = require('./services/content_service');

async function test() {
  const title = process.argv[2] || 'Tokyo Ghoul';
  const type = process.argv[3] || 'movie'; // 'movie' o 'tv'
  
  console.log('══════════════════════════════════════════════════════');
  console.log(`  AUTO-IMPORTACIÓN: "${title}" [Tipo: ${type}]`);
  console.log('══════════════════════════════════════════════════════\n');

  const result = await ContentService.autoImportByTitle(title, type);

  if (result.success) {
    console.log('\n✨ ¡CONTENIDO IMPORTADO CON ÉXITO! ✨');
    console.log('------------------------------------------------------');
    console.log(`🎬 Título oficial: ${result.data.title}`);
    console.log(`📂 Tipo:           ${result.data.type}`);
    console.log(`🆔 TMDB ID:        ${result.data.tmdbId}`);
    console.log(`📝 Sinopsis:       ${result.data.description.substring(0, 100)}...`);
    console.log('------------------------------------------------------');
  } else {
    console.error('\n❌ Error:', result.error);
  }

  process.exit();
}

test();
