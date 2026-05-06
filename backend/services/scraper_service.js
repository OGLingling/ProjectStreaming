const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

class VideoScraper {
  static normalizeMediaType(value) {
    const raw = String(value || '').toLowerCase().trim();
    return raw.includes('serie') || raw.includes('tv') ? 'tv' : 'movie';
  }

  static normalizePositiveInt(value, fallback) {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
  }

  static normalizeInput(value) {
    const raw = String(value || '').trim();
    if (!raw) return { input: '', tmdbId: null, isUrl: false };

    const isUrl = /^https?:\/\//i.test(raw);
    // Acepta hasta 20 dígitos — future-proof para IDs muy largos
    const tmdbMatch = raw.match(/tmdb[:=]?(\d+)/i) || raw.match(/^(\d{2,20})$/);
    const tmdbId = tmdbMatch ? tmdbMatch[1] : null;
    return { input: raw, tmdbId, isUrl };
  }

  static normalizeRequest(source) {
    // Strings inválidos que puede producir Dart cuando un campo es null
    const INVALID = new Set(['null', 'undefined', 'none', 'nan', '']);
    const sanitize = (v) => {
      if (v === undefined || v === null) return undefined;
      const s = String(v).trim();
      return INVALID.has(s.toLowerCase()) ? undefined : s;
    };

    if (source && typeof source === 'object') {
      const explicitTmdbId = sanitize(source.tmdbId) || sanitize(source.id);
      const sourceUrl = sanitize(source.url);
      const fallbackInput = sourceUrl || explicitTmdbId || '';
      const normalizedInput = this.normalizeInput(fallbackInput);

      return {
        input: String(fallbackInput).trim(),
        tmdbId: explicitTmdbId ?? normalizedInput.tmdbId,
        isUrl: normalizedInput.isUrl,
        type: this.normalizeMediaType(source.type),
        season: this.normalizePositiveInt(source.season, 1),
        episode: this.normalizePositiveInt(source.episode, 1)
      };
    }

    const normalizedInput = this.normalizeInput(source);
    return {
      ...normalizedInput,
      type: 'movie',
      season: 1,
      episode: 1
    };
  }

  static buildCandidates(source) {
    const { input, tmdbId, isUrl, type, season, episode } = this.normalizeRequest(source);
    if (!input && !tmdbId) return [];
    if (!tmdbId && isUrl) return [input];
    if (!tmdbId) return [];

    const isTV = type === 'tv';
    const vidsrcPath = isTV
      ? `tv/${tmdbId}/${season}/${episode}`
      : `movie/${tmdbId}`;
    const vidsrcQuery = isTV
      ? `tv?tmdb=${tmdbId}&season=${season}&episode=${episode}`
      : `movie?tmdb=${tmdbId}`;
    const smashyQuery = isTV
      ? `playere.php?tmdb=${tmdbId}&season=${season}&episode=${episode}`
      : `playere.php?tmdb=${tmdbId}`;
    const twoEmbedPath = isTV
      ? `embedtv/${tmdbId}&s=${season}&e=${episode}`
      : `embed/${tmdbId}`;

    const candidates = [
      `https://vidsrc.me/embed/${vidsrcPath}`,
      `https://vidsrc.to/embed/${vidsrcPath}`,
      `https://vidsrc.win/embed/${vidsrcPath}`,
      `https://vidsrc.wiki/embed/${vidsrcPath}`,
      `https://player.vidsrc.co/embed/${vidsrcPath}`,
      `https://vidsrc.me/embed/${vidsrcQuery}`,
      `https://vidsrc.to/embed/${vidsrcQuery}`,
      `https://vidsrc.win/embed/${vidsrcQuery}`,
      `https://embed.smashystream.com/${smashyQuery}`,
      `https://www.2embed.cc/${twoEmbedPath}`
    ];

    if (isUrl) {
      candidates.unshift(input);
    }

    return [...new Set(candidates)];
  }

  static createCandidatePayload(source) {
    const normalized = this.normalizeRequest(source);
    const candidates = this.buildCandidates(source);

    return {
      tmdbId: normalized.tmdbId,
      source: normalized.input,
      type: normalized.type,
      season: normalized.season,
      episode: normalized.episode,
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
        tmdbId: this.normalizeRequest(source).tmdbId,
        source: typeof source === 'object' ? JSON.stringify(source) : String(source || ''),
        providerMode: 'client-side-resolution',
        candidates: []
      };
    } finally {
      const success = !!(payload && payload.candidates && payload.candidates.length);
      await this.saveLog(
        typeof source === 'object' ? JSON.stringify(source) : String(source || ''),
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
