const axios = require('axios');

class TMDBApiService {
  constructor() {
    this.token = (process.env.TMDB_API_TOKEN || '').trim();
    this.apiKeyV3 = (process.env.TMDB_API_KEY || '').trim();
    // Usamos el dominio alternativo api.tmdb.org que suele estar menos bloqueado
    this.baseUrl = 'https://api.tmdb.org/3';
    this.imgBaseUrl = 'https://image.tmdb.org/t/p/original';
  }

  get headers() {
    return {
      Authorization: `Bearer ${this.token}`,
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
    };
  }

  async getFullMetadata(tmdbId, type = 'movie') {
    try {
      // Intentamos con la API Key v3 en la URL si está disponible
      const authParam = this.apiKeyV3 ? `api_key=${this.apiKeyV3}&` : '';
      const url = `${this.baseUrl}/${type}/${tmdbId}?${authParam}append_to_response=videos,credits&language=es-ES`;
      
      console.log(`[tmdb-api] 📡 Llamando a: ${url.replace(this.apiKeyV3, '***')}`);
      
      // Si usamos api_key en la URL, no mandamos la cabecera Authorization para evitar conflictos
      const config = { headers: { ...this.headers } };
      if (this.apiKeyV3) delete config.headers.Authorization;

      const response = await axios.get(url, config);
      const data = response.data;

      // LOG DE DIAGNÓSTICO
      if (!data.id) {
        console.log('[tmdb-api] 🔍 Datos recibidos:', JSON.stringify(data).substring(0, 200));
        return { success: false, error: 'Respuesta de TMDB inválida (Falta ID)' };
      }

      const trailer = data.videos?.results?.find(v => v.type === 'Trailer' && v.site === 'YouTube') || data.videos?.results?.[0];

      return {
        success: true,
        data: {
          tmdbId: String(data.id),
          title: data.title || data.name || data.original_name,
          description: data.overview,
          releaseDate: data.release_date || data.first_air_date,
          rating: data.vote_average,
          category: data.genres?.map(g => g.name).join(', '),
          imageUrl: data.poster_path ? `${this.imgBaseUrl}${data.poster_path}` : null,
          backdropUrl: data.backdrop_path ? `${this.imgBaseUrl}${data.backdrop_path}` : null,
          trailerUrl: trailer ? `https://www.youtube.com/watch?v=${trailer.key}` : null,
          type: type === 'movie' ? 'movie' : 'series',
          cast: data.credits?.cast?.slice(0, 10).map(actor => ({
            name: actor.name,
            character: actor.character,
            profileUrl: actor.profile_path ? `${this.imgBaseUrl}${actor.profile_path}` : null
          })) || []
        },
        raw: data // Guardamos la respuesta completa para acceder a temporadas/episodios
      };
    } catch (error) {
      const msg = error.response?.data?.status_message || error.message;
      console.error(`[tmdb-api] ❌ Error: ${msg}`);
      return { success: false, error: msg };
    }
  }

  /**
   * Busca contenido por título y devuelve el primer resultado
   * @param {string} query Título a buscar
   * @param {string} type "movie" o "tv"
   */
  async searchContent(query, type = 'movie') {
    try {
      const authParam = this.apiKeyV3 ? `api_key=${this.apiKeyV3}&` : '';
      const url = `${this.baseUrl}/search/${type}?${authParam}query=${encodeURIComponent(query)}&language=es-ES`;
      
      const response = await axios.get(url, { headers: this.headers });
      const results = response.data.results;

      if (!results || results.length === 0) {
        return { success: false, error: 'No se encontraron resultados' };
      }

      // Devolvemos el primer resultado (el más relevante)
      return { success: true, data: results[0] };
    } catch (error) {
      console.error(`[tmdb-api] ❌ Error en búsqueda:`, error.message);
      return { success: false, error: error.message };
    }
  }
}

module.exports = new TMDBApiService();
