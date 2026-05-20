const { PrismaClient } = require('@prisma/client');
const TMDBApi = require('./tmdb_api_service');
const prisma = new PrismaClient();

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
        for (const s of raw.seasons) {
          try {
            if (s.season_number === 0 && !s.episode_count) {
              continue;
            }

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

  async getAllContent() {
    return await prisma.content.findMany({
      orderBy: { createdAt: 'desc' }
    });
  }
}

module.exports = new ContentService();
