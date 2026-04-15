const axios = require('axios');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Configuración de TMDB
const TMDB_API_KEY = 'd8a00b94f5c00821e497b569fec9a61f'; 
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

/**
 * Enriquece los datos básicos de la base de datos con información 
 * en tiempo real de TMDB (Posters, Backdrops, Ratings actualizados).
 */
async function enrichMovieData(movie) {
    const identifier = movie.tmdbId || movie.imdbId;
    if (!identifier) return movie;

    try {
        let apiUrl;
        if (movie.tmdbId) {
            const path = movie.type === 'tv' ? 'tv' : 'movie';
            apiUrl = `${TMDB_BASE_URL}/${path}/${movie.tmdbId}?api_key=${TMDB_API_KEY}&language=es-ES`;
        } else {
            apiUrl = `${TMDB_BASE_URL}/find/${movie.imdbId}?api_key=${TMDB_API_KEY}&external_source=imdb_id&language=es-ES`;
        }

        const response = await axios.get(apiUrl);
        const data = movie.tmdbId 
            ? response.data 
            : (response.data.movie_results[0] || response.data.tv_results[0]);

        if (data) {
            return {
                ...movie, // Mantiene seasons y episodes traídos por Prisma
                title: data.title || data.name || movie.title,
                description: data.overview || movie.description,
                imageUrl: data.poster_path ? `https://image.tmdb.org/t/p/w500${data.poster_path}` : movie.imageUrl,
                backdropUrl: data.backdrop_path ? `https://image.tmdb.org/t/p/original${data.backdrop_path}` : movie.backdropUrl,
                rating: data.vote_average ? parseFloat(data.vote_average.toFixed(1)) : (movie.rating || 0.0),
            };
        }
    } catch (error) {
        console.error(`[TMDB Enriquecimiento Fallido] ID ${identifier}:`, error.message);
    }
    return movie;
}

/**
 * Obtiene el catálogo de películas y series con sus respectivas 
 * temporadas y episodios anidados.
 */
exports.getMovies = async (req, res) => {
    const { type } = req.query;
    try {
        let whereCondition = {};
        
        if (type) {
            const normalizedType = type.toLowerCase().trim().replace('s', '');
            whereCondition = {
                type: {
                    contains: normalizedType,
                    mode: 'insensitive'
                }
            };
        }

        // CONSULTA MAESTRA: Trae la película + Temporadas + Episodios
        const content = await prisma.movie.findMany({
            where: whereCondition,
            include: {
                seasons: {
                    include: {
                        episodes: {
                            orderBy: {
                                episodeNumber: 'asc' // Ordena episodios: 1, 2, 3...
                            }
                        }
                    },
                    orderBy: {
                        seasonNumber: 'asc' // Ordena temporadas: 1, 2, 3...
                    }
                }
            },
            orderBy: { createdAt: 'desc' }
        });

        // Enriquecemos cada película/serie con datos de TMDB de forma paralela
        const enrichedContent = await Promise.all(
            content.map(movie => enrichMovieData(movie))
        );

        res.json(enrichedContent);
    } catch (error) {
        console.error("Error crítico en GET /api/movies:", error);
        res.status(500).json({ 
            error: "Error interno al cargar el catálogo",
            details: error.message 
        });
    }
};

/**
 * Proxy para el reproductor de video para evitar bloqueos de CORS 
 * y manejar rutas relativas de scripts/estilos.
 */
exports.proxyStream = async (req, res) => {
    const targetUrl = req.query.url;
    if (!targetUrl) return res.status(400).send("URL de streaming requerida");

    try {
        const response = await axios.get(targetUrl, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
                'Referer': new URL(targetUrl).origin,
                'Origin': new URL(targetUrl).origin
            },
            timeout: 15000 
        });

        res.set('Content-Type', 'text/html');
        let html = response.data;
        const origin = new URL(targetUrl).origin;
        
        // Inyectamos la etiqueta <base> para que los assets del iframe carguen correctamente
        html = html.replace('<head>', `<head><base href="${origin}/">`);
        
        res.send(html);

    } catch (error) {
        console.error("Error en Proxy Stream:", error.message);
        res.status(200).send(`
            <body style="background:#000;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;font-family:sans-serif;">
                <div style="text-align:center;">
                    <p style="font-size: 1.2rem;">El servidor de video no está disponible en este momento.</p>
                    <button onclick="window.location.reload()" style="background:#E50914;color:white;border:none;padding:12px 24px;border-radius:4px;cursor:pointer;font-weight:bold;margin-top:10px;">REINTENTAR</button>
                </div>
            </body>
        `);
    }
};