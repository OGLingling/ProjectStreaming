const { PrismaClient } = require('@prisma/client');
const fs = require('fs');
const path = require('path');
const TMDBApi = require('./tmdb_api_service');
const prisma = new PrismaClient();

const TMDB_IMAGE_BASE_URL = 'https://image.tmdb.org/t/p/original';
const LOCAL_DATASET_DIR = path.resolve(__dirname);
const LEGACY_DATASET_DIR = 'C:\\Users\\Usuario\\Desktop\\tmdb_dataset';
const TMDB_DATASET_DIR = process.env.TMDB_DATASET_DIR
  || (fs.existsSync(path.join(LOCAL_DATASET_DIR, 'movies.json')) ? LOCAL_DATASET_DIR : LEGACY_DATASET_DIR);
const DATASET_IMPORT_LIMIT = Number.parseInt(process.env.DATASET_IMPORT_LIMIT || '500', 10);

const SERIES_EPISODE_OVERRIDES = {
  '37854': [1160], // One Piece
  '65942': [25, 25, 16, 19], // Re:ZERO -Starting Life in Another World-
  '209867': [28, 10], // Frieren: Beyond Journey's End
  '79744': [20, 20, 14, 22, 22, 10, 18, 18], // The Rookie
  '85552': [8, 8, 8, { seasonNumber: 0, episodeCount: 2, title: 'Especiales' }], // Euphoria
  '61374': [12, 12, 12, 12], // Tokyo Ghoul
  '95479': [24, 23, 13], // JUJUTSU KAISEN
  '95557': [8, 8, 6, 8], // Invincible
};

const SERIES_SEASON_TITLE_OVERRIDES = {
  '37854': ['Episodios'], // One Piece no se muestra dividido por temporadas
};

function readJsonFile(filePath) {
  if (!fs.existsSync(filePath)) return [];

  try {
    const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    return Array.isArray(parsed) ? parsed : [];
  } catch (error) {
    console.warn(`[content-service] No se pudo leer dataset ${filePath}:`, error.message);
    return [];
  }
}

function parseJsonArray(value) {
  if (!value) return [];

  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

function imageUrl(imagePath) {
  return imagePath ? `${TMDB_IMAGE_BASE_URL}${imagePath}` : null;
}

function loadDatasetMovies() {
  const moviesPath = path.join(TMDB_DATASET_DIR, 'movies.json');
  const creditsPath = path.join(TMDB_DATASET_DIR, 'credits.json');
  const movies = readJsonFile(moviesPath);
  const credits = readJsonFile(creditsPath);
  const creditsByMovieId = new Map(
    credits
      .filter((credit) => credit.movie_id != null)
      .map((credit) => [String(credit.movie_id), credit])
  );

  return movies
    .filter((movie) => movie.id != null)
    .map((movie) => ({
      ...movie,
      credits: creditsByMovieId.get(String(movie.id)) || null,
    }));
}

function datasetMovieData(movie) {
  const category = parseJsonArray(movie.genres)
    .map((genre) => genre?.name)
    .filter(Boolean)
    .join(', ');

  return {
    tmdbId: String(movie.id),
    title: movie.title || movie.original_title || 'Sin titulo',
    description: movie.overview || null,
    releaseDate: movie.release_date || null,
    imageUrl: imageUrl(movie.poster_path),
    backdropUrl: imageUrl(movie.backdrop_path),
    trailerUrl: null,
    type: 'movie',
    category: category || null,
    rating: Number(movie.vote_average) || 0,
  };
}

function datasetMovieUpdateData(movie) {
  const data = datasetMovieData(movie);

  return {
    title: data.title,
    description: data.description,
    releaseDate: data.releaseDate,
    type: data.type,
    category: data.category,
    rating: data.rating,
    ...(data.imageUrl ? { imageUrl: data.imageUrl } : {}),
    ...(data.backdropUrl ? { backdropUrl: data.backdropUrl } : {}),
  };
}

function hasMissingImages(content) {
  return !content.imageUrl || !content.backdropUrl;
}

function imageUpdatePayload(metadata) {
  const payload = {};
  if (metadata?.imageUrl) payload.imageUrl = metadata.imageUrl;
  if (metadata?.backdropUrl) payload.backdropUrl = metadata.backdropUrl;
  return payload;
}

async function fetchImageMetadata(tmdbId, type = 'movie') {
  const normalizedType = type === 'tv' ? 'tv' : 'movie';

  try {
    const apiResult = await TMDBApi.getFullMetadata(tmdbId, normalizedType);
    if (apiResult.success && (apiResult.data?.imageUrl || apiResult.data?.backdropUrl)) {
      return {
        imageUrl: apiResult.data.imageUrl || null,
        backdropUrl: apiResult.data.backdropUrl || null,
      };
    }
  } catch (error) {
    console.warn(`[content-service] TMDB API no devolvio imagenes para ${normalizedType}/${tmdbId}:`, error.message);
  }

  return null;
}

async function syncSeasonEpisodes(seasonId, episodes) {
  const validEpisodeNumbers = episodes
    .map((episode) => Number(episode.episodeNumber))
    .filter((episodeNumber) => Number.isInteger(episodeNumber) && episodeNumber > 0);

  for (const episode of episodes) {
    const episodeNumber = Number(episode.episodeNumber);
    if (!Number.isInteger(episodeNumber) || episodeNumber <= 0) continue;

    const existing = await prisma.episode.findFirst({
      where: { seasonId, episodeNumber },
      select: { id: true },
    });

    const data = {
      episodeNumber,
      title: episode.title,
      description: episode.description,
      stillPath: episode.stillPath,
      duration: episode.duration,
      seasonId,
    };

    if (existing) {
      await prisma.episode.update({
        where: { id: existing.id },
        data,
      });
    } else {
      await prisma.episode.create({ data });
    }
  }

  if (validEpisodeNumbers.length > 0) {
    await prisma.episode.deleteMany({
      where: {
        seasonId,
        episodeNumber: { notIn: validEpisodeNumbers },
      },
    });
  }
}

async function fetchAvailableEpisodes(tmdbId, seasons) {
  const episodesBySeason = new Map();

  for (const season of seasons) {
    try {
      const seasonResult = await TMDBApi.getSeasonDetails(tmdbId, season.season_number);
      if (seasonResult.success) {
        episodesBySeason.set(Number(season.season_number), seasonResult.data);
      }
    } catch (error) {
      console.warn(`[content-service] No se pudo leer TMDB ${tmdbId} temporada ${season.season_number}:`, error.message);
    }
  }

  return episodesBySeason;
}

function normalizeSeasonOverride(override, index) {
  if (typeof override === 'number') {
    return {
      seasonNumber: index + 1,
      episodeCount: override,
      title: null,
    };
  }

  return {
    seasonNumber: override.seasonNumber ?? index + 1,
    episodeCount: override.episodeCount,
    title: override.title || null,
  };
}

async function syncOverriddenSeasons(contentId, tmdbId, seasons, episodeCounts) {
  const tmdbSeasons = await fetchAvailableEpisodes(tmdbId, seasons);
  const validSeasonNumbers = episodeCounts.map((override, index) => normalizeSeasonOverride(override, index).seasonNumber);

  for (const [index, override] of episodeCounts.entries()) {
    const { seasonNumber, episodeCount, title: titleOverride } = normalizeSeasonOverride(override, index);
    const originalSeason = seasons.find((season) => season.season_number === seasonNumber);
    const tmdbSeason = tmdbSeasons.get(Number(seasonNumber));
    const seasonTmdbId = tmdbSeason?.tmdbId || (originalSeason?.id ? String(originalSeason.id) : `${tmdbId}-season-${seasonNumber}`);
    const title = titleOverride || SERIES_SEASON_TITLE_OVERRIDES[tmdbId]?.[index] || tmdbSeason?.title || originalSeason?.name || `Temporada ${seasonNumber}`;

    const season = await prisma.season.upsert({
      where: { tmdbId: seasonTmdbId },
      update: {
        seasonNumber,
        title,
        contentId,
      },
      create: {
        tmdbId: seasonTmdbId,
        seasonNumber,
        title,
        contentId,
      },
    });

    const episodes = Array.from({ length: episodeCount }, (_, episodeIndex) => {
      const episodeNumber = episodeIndex + 1;
      const tmdbEpisode = tmdbSeason?.episodes?.find((episode) => episode.episodeNumber === episodeNumber);

      return {
        episodeNumber,
        title: tmdbEpisode?.title || `Episodio ${episodeNumber}`,
        description: tmdbEpisode?.description || null,
        stillPath: tmdbEpisode?.stillPath || null,
        duration: tmdbEpisode?.duration || null,
      };
    });

    await syncSeasonEpisodes(season.id, episodes);
  }

  await prisma.season.deleteMany({
    where: {
      contentId,
      seasonNumber: { notIn: validSeasonNumbers },
    },
  });
}

class ContentService {
  /**
   * Importa o actualiza contenido desde TMDB a la base de datos
   * @param {string} tmdbId ID de la película o serie
   * @param {string} type "movie" o "tv"
   */
  async importFromTMDB(tmdbId, type = 'movie') {
    const normalizedType = type === 'movie' ? 'movie' : 'tv';
    console.log(`[content-service] 🎬 Iniciando importación de ${normalizedType} ID: ${tmdbId}`);

    try {
      // 1. Obtener metadata de la API
      const result = await TMDBApi.getFullMetadata(tmdbId, normalizedType);
      if (!result.success) {
        // Si falló con 'tv', intentamos con 'movie' como fallback (para OVAs/Especiales)
        if (normalizedType === 'tv') {
          console.log(`[content-service] 🔄 Falló como TV, reintentando como movie...`);
          const fallback = await TMDBApi.getFullMetadata(tmdbId, 'movie');
          if (fallback.success) return await this.importFromTMDB(tmdbId, 'movie');
        }
        throw new Error(result.error || 'No se pudo obtener información de TMDB');
      }

      const data = result.data;
      const raw = result.raw;

      // 2. Upsert del Contenido Principal
      const content = await prisma.content.upsert({
        where: { tmdbId: String(tmdbId) },
        update: {
          title: data.title,
          description: data.description,
          releaseDate: data.releaseDate,
          rating: data.rating || 0,
          category: data.category,
          imageUrl: data.imageUrl,
          backdropUrl: data.backdropUrl,
          trailerUrl: data.trailerUrl,
          type: normalizedType,
        },
        create: {
          tmdbId: String(tmdbId),
          title: data.title,
          description: data.description,
          releaseDate: data.releaseDate,
          rating: data.rating || 0,
          category: data.category,
          imageUrl: data.imageUrl,
          backdropUrl: data.backdropUrl,
          trailerUrl: data.trailerUrl,
          type: normalizedType,
        }
      });

      // 3. Importación de Temporadas (solo si es TV y tenemos datos raw)
      if (normalizedType === 'tv' && raw && raw.seasons) {
        console.log(`[content-service] 📂 Importando ${raw.seasons.length} temporadas...`);
        const availableSeasons = raw.seasons.filter((s) => (s.episode_count || 0) > 0);
        const episodeOverride = SERIES_EPISODE_OVERRIDES[String(tmdbId)];

        if (episodeOverride) {
          await syncOverriddenSeasons(content.id, String(tmdbId), availableSeasons, episodeOverride);
        } else {
          for (const s of availableSeasons.filter((season) => season.season_number > 0)) {
            try {

              const season = await prisma.season.upsert({
                where: { tmdbId: String(s.id) },
                update: {
                  seasonNumber: s.season_number,
                  title: s.name,
                  contentId: content.id
                },
                create: {
                  tmdbId: String(s.id),
                  seasonNumber: s.season_number,
                  title: s.name,
                  contentId: content.id
                }
              });

              const seasonResult = await TMDBApi.getSeasonDetails(tmdbId, s.season_number);
              if (!seasonResult.success) {
                console.warn(`[content-service] No se pudieron importar episodios de temporada ${s.season_number}: ${seasonResult.error}`);
                continue;
              }

              await syncSeasonEpisodes(season.id, seasonResult.data.episodes);
            } catch (seasonErr) {
              console.warn(`[content-service] ⚠ No se pudo importar temporada ${s.season_number}:`, seasonErr.message);
            }
          }
        }
      }

      console.log(`[content-service] ✅ Contenido "${content.title}" (${normalizedType}) procesado.`);
      return { success: true, data: content };

    } catch (error) {
      console.error(`[content-service] ❌ Error crítico:`, error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Busca por nombre y tipo, luego importa
   */
  async autoImportByTitle(title, type = 'movie') {
    const normalizedType = type === 'movie' ? 'movie' : 'tv';
    console.log(`[content-service] 🔍 Buscando "${title}" (${normalizedType})...`);

    try {
      const searchResult = await TMDBApi.searchContent(title, normalizedType);

      // Fallback: si no encuentra como TV, busca como movie
      if (!searchResult.success && normalizedType === 'tv') {
        console.log(`[content-service] 🔄 No encontrado como TV, buscando como movie...`);
        const fallbackSearch = await TMDBApi.searchContent(title, 'movie');
        if (fallbackSearch.success) {
          return await this.importFromTMDB(fallbackSearch.data.id, 'movie');
        }
      }

      if (!searchResult.success) {
        return { success: false, error: 'No se encontró nada en TMDB con ese nombre.' };
      }

      return await this.importFromTMDB(searchResult.data.id, normalizedType);

    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async importMoviesFromDataset({ limit } = {}) {
    const datasetMovies = loadDatasetMovies();
    const requestedLimit = Number.isInteger(limit) && limit > 0
      ? limit
      : DATASET_IMPORT_LIMIT;
    const safeLimit = Number.isInteger(requestedLimit) && requestedLimit > 0
      ? Math.min(requestedLimit, 500)
      : 500;
    const moviesToImport = safeLimit > 0
      ? datasetMovies.slice(0, safeLimit)
      : datasetMovies;
    let imported = 0;
    let withoutImages = 0;

    for (const movie of moviesToImport) {
      const data = datasetMovieData(movie);

      if (!data.imageUrl || !data.backdropUrl) {
        const metadata = await fetchImageMetadata(data.tmdbId, 'movie');
        const imagePayload = imageUpdatePayload(metadata);
        data.imageUrl = data.imageUrl || imagePayload.imageUrl || null;
        data.backdropUrl = data.backdropUrl || imagePayload.backdropUrl || null;
      }

      if (!data.imageUrl && !data.backdropUrl) {
        withoutImages++;
        console.warn(`[content-service] Pelicula TMDB ${data.tmdbId} importada sin imagen disponible.`);
      }

      await prisma.content.upsert({
        where: { tmdbId: data.tmdbId },
        update: {
          ...datasetMovieUpdateData(movie),
          ...(data.imageUrl ? { imageUrl: data.imageUrl } : {}),
          ...(data.backdropUrl ? { backdropUrl: data.backdropUrl } : {}),
        },
        create: data,
      });

      imported++;
    }

    console.log(`[content-service] Dataset de peliculas sincronizado: ${imported}/${datasetMovies.length} (limite ${moviesToImport.length}, sin imagen ${withoutImages})`);
    return { success: true, imported, total: datasetMovies.length, withoutImages };
  }

  async enrichMissingImages({ limit, type } = {}) {
    const normalizedType = type === 'tv' ? 'tv' : type === 'movie' ? 'movie' : undefined;
    const where = {
      tmdbId: { not: null },
      OR: [
        { imageUrl: null },
        { imageUrl: '' },
        { backdropUrl: null },
        { backdropUrl: '' },
      ],
      ...(normalizedType ? { type: normalizedType } : {}),
    };

    const contents = await prisma.content.findMany({
      where,
      take: Number.isInteger(limit) && limit > 0 ? limit : undefined,
      orderBy: { id: 'asc' },
      select: {
        id: true,
        tmdbId: true,
        type: true,
        title: true,
        imageUrl: true,
        backdropUrl: true,
      },
    });
    let updated = 0;
    let skipped = 0;

    for (const content of contents) {
      if (!hasMissingImages(content)) {
        skipped++;
        continue;
      }

      const metadata = await fetchImageMetadata(content.tmdbId, content.type);
      const payload = imageUpdatePayload(metadata);

      if (Object.keys(payload).length === 0) {
        skipped++;
        continue;
      }

      await prisma.content.update({
        where: { id: content.id },
        data: {
          ...(!content.imageUrl && payload.imageUrl ? { imageUrl: payload.imageUrl } : {}),
          ...(!content.backdropUrl && payload.backdropUrl ? { backdropUrl: payload.backdropUrl } : {}),
        },
      });
      updated++;
      console.log(`[content-service] Imagenes actualizadas: ${content.title} (${content.type}/${content.tmdbId})`);
    }

    return { success: true, scanned: contents.length, updated, skipped };
  }

  async getAllContent() {
    return await prisma.content.findMany({
      orderBy: { createdAt: 'desc' }
    });
  }
}

module.exports = new ContentService();
