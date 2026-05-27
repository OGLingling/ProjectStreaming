const axios = require('axios');

/**
 * Valida si una URL de streaming (especialmente .m3u8 HLS) está activa y es válida.
 * Realiza una petición rápida con timeout de 5 segundos, verificando status 200
 * y la cabecera #EXTM3U.
 * 
 * @param {string} url - URL de streaming a validar.
 * @returns {Promise<boolean>} True si la URL es válida y reproducible, false de lo contrario.
 */
async function validateM3u8Url(url) {
  if (!url || typeof url !== 'string') return false;

  const cleanUrl = url.trim();

  // Si no es m3u8, podemos validar con una petición HEAD rápida para verificar status 200/206 (por ejemplo, para .mp4 o videoplayback)
  const isM3u8 = cleanUrl.toLowerCase().includes('.m3u8');

  try {
    console.log(`[validator] 🔍 Iniciando validación HTTP rápida para: ${cleanUrl.substring(0, 80)}...`);
    
    if (isM3u8) {
      const response = await axios.get(cleanUrl, {
        timeout: 5000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8,en-US;q=0.7',
          'Origin': 'https://embed.smashystream.com',
          'Referer': 'https://embed.smashystream.com/'
        }
      });

      if (response.status !== 200) {
        console.warn(`[validator] ⚠️ Estatus HTTP inválido para M3U8: ${response.status}`);
        return false;
      }

      const body = String(response.data || '');
      const hasExtM3u = body.includes('#EXTM3U');

      if (!hasExtM3u) {
        console.warn(`[validator] ⚠️ El cuerpo no contiene la cabecera #EXTM3U`);
        return false;
      }

      console.log(`[validator] ✅ URL M3U8 válida y activa (contiene #EXTM3U)`);
      return true;
    } else {
      // Para otras URLs de streaming directas (ej. .mp4 o videoplayback)
      const response = await axios.head(cleanUrl, {
        timeout: 5000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
        }
      });

      const isValidStatus = response.status >= 200 && response.status < 300;
      if (!isValidStatus) {
        console.warn(`[validator] ⚠️ Estatus HTTP inválido para streaming directo: ${response.status}`);
        return false;
      }

      console.log(`[validator] ✅ URL de streaming directo activa (estatus ${response.status})`);
      return true;
    }
  } catch (error) {
    console.error(`[validator] ❌ Error al validar la URL: ${error.message}`);
    return false;
  }
}

module.exports = { validateM3u8Url };
