const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

class VideoScraper {
  static normalizeInput(value) {
    const raw = String(value || '').trim();
    if (!raw) return { input: '', tmdbId: null, isUrl: false };

    const isUrl = /^https?:\/\//i.test(raw);
    const tmdbMatch = raw.match(/tmdb[:=]?(\d+)/i) || raw.match(/^(\d{2,10})$/);
    const tmdbId = tmdbMatch ? tmdbMatch[1] : null;
    return { input: raw, tmdbId, isUrl };
  }

  static buildCandidates(source) {
    const { input, tmdbId, isUrl } = this.normalizeInput(source);
    if (!input) return [];
    if (isUrl) return [input];
    if (!tmdbId) return [];

    // Catálogo de proveedores embebidos para resolución client-side en la APK.
    return [
      `https://vidsrc.me/embed/movie/${tmdbId}`,
      `https://vidsrc.to/embed/movie/${tmdbId}`,
      `https://vidsrc.win/embed/movie/${tmdbId}`,
      `https://embed.smashystream.com/playere.php?tmdb=${tmdbId}`,
      `https://www.2embed.cc/embed/${tmdbId}`
    ];
  }

  static createCandidatePayload(source) {
    const normalized = this.normalizeInput(source);
    const candidates = this.buildCandidates(source);

    return {
      tmdbId: normalized.tmdbId,
      source: normalized.input,
      providerMode: 'client-side-resolution',
      candidates
    };
  }

  static async extractStreamUrl(source) {
    const start = Date.now();
    let payload = null;
    let err = null;

    try {
      payload = this.createCandidatePayload(source);
      if (!payload.candidates.length) {
        throw new Error('No se pudieron generar candidatos para el ID/URL recibido');
      }
      return payload;
    } catch (e) {
      err = e.message;
      return {
        tmdbId: this.normalizeInput(source).tmdbId,
        source: String(source || ''),
        providerMode: 'client-side-resolution',
        candidates: []
      };
    } finally {
      const success = !!(payload && payload.candidates && payload.candidates.length);
      await this.saveLog(
        String(source || ''),
        success,
        payload ? JSON.stringify(payload.candidates) : null,
        err,
        Date.now() - start
      );
    }
  }

  static async saveLog(targetUrl, success, result, error, duration) {
    try {
      await prisma.scrapeLog.create({
        data: {
          targetUrl,
          success,
          streamUrl: result,
          error,
          duration
        }
      });
    } catch (dbError) {
      console.error('Error BD Log:', dbError.message);
    }
  }
}

module.exports = VideoScraper;

/**
 * IMPLEMENTACIÓN RECOMENDADA EN LA APK (WEBVIEW OCULTO):
 * 1) Consumir /api/extract?url=<tmdbId_o_url> y obtener `candidates`.
 * 2) Crear un WebView oculto por cada candidato (secuencial, no paralelo agresivo).
 * 3) Cargar el embed y enganchar el interceptador de red del WebView.
 * 4) Filtrar requests/responses que contengan:
 *    - ".m3u8"
 *    - ".mp4"
 *    - "master.m3u8"
 * 5) Ignorar tráfico de audio, trailers y publicidad.
 * 6) Cuando se detecte el primer stream válido, cerrar WebView actual y detener la búsqueda.
 * 7) Reproducir usando ese stream real (IP residencial del usuario), evitando el bloqueo a Data Centers.
 * 8) Si no hay match en un candidato, cerrar el WebView y continuar con el siguiente.
 * 9) Implementar timeout por candidato (10-20s) y timeout global para no bloquear la UI.
 * 10) Guardar telemetría local (proveedor, tiempo, éxito) para priorizar candidatos más estables.
 */
