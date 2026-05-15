const { PrismaClient } = require('@prisma/client');
const TMDBApi = require('./tmdb_api_service');
const prisma = new PrismaClient();

class ContentService {
  /**
   * Importa o actualiza contenido desde TMDB a la base de datos
   * @param {string} tmdbId ID de la película o serie
   * @param {string} type "movie" o "tv"
   */
  async importFromTMDB(tmdbId, type = 'movie') {
    console.log(`[content-service] 🎬 Iniciando importación de ${type} ID: ${tmdbId}`);

    try {
      // 1. Obtener metadata de la API
      const result = await TMDBApi.getFullMetadata(tmdbId, type);
      if (!result.success) {
        throw new Error(result.error);
      }

      const data = result.data;

      // 2. Insertar o Actualizar en la base de datos (Upsert)
      const content = await prisma.content.upsert({
        where: { tmdbId: String(tmdbId) },
        update: {
          title: data.title,
          description: data.description,
          releaseDate: data.releaseDate,
          rating: data.rating,
          category: data.category,
          imageUrl: data.imageUrl,
          backdropUrl: data.backdropUrl,
          trailerUrl: data.trailerUrl,
          type: type === 'movie' ? 'movie' : 'series',
        },
        create: {
          tmdbId: String(tmdbId),
          title: data.title,
          description: data.description,
          releaseDate: data.releaseDate,
          rating: data.rating,
          category: data.category,
          imageUrl: data.imageUrl,
          backdropUrl: data.backdropUrl,
          trailerUrl: data.trailerUrl,
          type: type === 'movie' ? 'movie' : 'tv',
        }
      });

      // 3. Si es una serie, importar temporadas básicas
      if (type === 'tv' || type === 'series') {
        const fullData = await TMDBApi.getFullMetadata(tmdbId, 'tv');
        // Aquí podrías expandir para traer episodios, pero por ahora creamos las temporadas
        if (fullData.success && result.raw) {
          const seasons = result.raw.seasons || [];
          for (const s of seasons) {
            await prisma.season.upsert({
              where: { tmdbId: String(s.id) },
              update: { seasonNumber: s.season_number, title: s.name },
              create: {
                tmdbId: String(s.id),
                seasonNumber: s.season_number,
                title: s.name,
                contentId: content.id
              }
            });
          }
        }
      }

      console.log(`[content-service] ✅ Contenido "${content.title}" guardado en DB (ID: ${content.id})`);
      return { success: true, data: content };

    } catch (error) {
      console.error(`[content-service] ❌ Error importando TMDB ${tmdbId}:`, error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Busca una película o serie por nombre y la importa automáticamente
   */
  async autoImportByTitle(title, type = 'movie') {
    console.log(`[content-service] 🔍 Buscando "${title}" para auto-importar...`);
    
    try {
      // 1. Buscar el ID en TMDB
      const searchResult = await TMDBApi.searchContent(title, type);
      if (!searchResult.success) {
        throw new Error(searchResult.error);
      }

      const tmdbId = searchResult.data.id;
      console.log(`[content-service] 🎯 Encontrado: "${searchResult.data.title || searchResult.data.name}" (ID: ${tmdbId})`);

      // 2. Importar usando el ID encontrado
      return await this.importFromTMDB(tmdbId, type);

    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  /**
   * Obtiene todo el contenido de la base de datos
   */
  async getAllContent() {
    return await prisma.content.findMany({
      orderBy: { createdAt: 'desc' }
    });
  }
}

module.exports = new ContentService();
