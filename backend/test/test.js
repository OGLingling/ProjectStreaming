// Importamos el servicio (asegúrate de que el nombre del archivo coincida)
const VideoScraper = require('./scraper_service.js');

async function ejecutarPrueba() {
  const idPrueba = '823464'; // Godzilla x Kong (ejemplo)
  
  console.log(`--- INICIANDO PRUEBA PARA ID: ${idPrueba} ---`);
  console.log("Paso 1: Construyendo candidatos...");
  
  try {
    // Llamamos directamente a la función de extracción
    const urlEncontrada = await VideoScraper.extractStreamUrl(idPrueba);
    
    console.log("-----------------------------------------");
    if (urlEncontrada) {
      console.log("✅ ¡ÉXITO TOTAL!");
      console.log("URL DEL VIDEO:", urlEncontrada);
    } else {
      console.log("❌ FALLO: El scraper terminó pero no encontró ninguna URL.");
      console.log("Revisa los logs de arriba para ver dónde se detuvo.");
    }
    console.log("-----------------------------------------");

  } catch (error) {
    console.error("💥 ERROR CRÍTICO DURANTE LA PRUEBA:", error.message);
  } finally {
    // Forzamos el cierre del proceso para que no se quede colgado
    process.exit();
  }
}

ejecutarPrueba();