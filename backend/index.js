const express = require('express');
const cors = require('cors');
const axios = require('axios');
const { PrismaClient } = require('@prisma/client');

const app = express();
const prisma = new PrismaClient();

// --- CONFIGURACIÓN TMDB ---
const TMDB_API_KEY = 'd8a00b94f5c00821e497b569fec9a61f'; 
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    credentials: true
}));

app.use(express.json());

// ==========================================
//   LÓGICA DE PELÍCULAS (ENRIQUECIMIENTO)
// ==========================================

async function enrichMovieData(movie) {
    const identifier = movie.tmdbId || movie.imdbId;
    if (!identifier) return movie;

    try {
        let apiUrl;
        if (movie.tmdbId) {
            const path = movie.type === 'tv' ? 'tv' : 'movie';
            apiUrl = `${TMDB_BASE_URL}/${path}/${movie.tmdbId}?api_key=${TMDB_API_KEY}&language=es-ES&append_to_response=videos`;
        } else {
            apiUrl = `${TMDB_BASE_URL}/find/${movie.imdbId}?api_key=${TMDB_API_KEY}&external_source=imdb_id&language=es-ES`;
        }

        const response = await axios.get(apiUrl, { timeout: 2000 });
        
        const data = movie.tmdbId 
            ? response.data 
            : (response.data.movie_results[0] || response.data.tv_results[0]);

        if (data) {
            // Buscamos el trailer oficial en YouTube
            const trailer = data.videos?.results?.find(v => v.type === 'Trailer' && v.site === 'YouTube');

            return {
                ...movie,
                title: data.title || data.name || movie.title,
                description: data.overview || movie.description,
                imageUrl: data.poster_path ? `https://image.tmdb.org/t/p/w500${data.poster_path}` : movie.imageUrl,
                backdropUrl: data.backdrop_path ? `https://image.tmdb.org/t/p/original${data.backdrop_path}` : movie.backdropUrl,
                rating: data.vote_average ? parseFloat(data.vote_average.toFixed(1)) : (movie.rating || 0.0),
                // Si la DB tiene trailerUrl lo respeta, si no, usa el de TMDB
                trailerUrl: movie.trailerUrl || (trailer ? `https://www.youtube.com/watch?v=${trailer.key}` : null),
            };
        }
    } catch (error) {
        console.error(`[TMDB Skip] ID ${identifier}: ${error.code || 'Error'}`);
    }
    return movie;
}

app.get(['/api/movies', '/movies'], async (req, res) => {
    try {
        const { type } = req.query;
        let whereCondition = {};
        
        if (type) {
            // Convierte "Pelicula" o "Serie" a los términos que entiende tu lógica (movie/tv)
            const normalizedType = type.toLowerCase().startsWith('peli') ? 'movie' : 'tv';
            whereCondition = { type: normalizedType };
        }

        const content = await prisma.movie.findMany({
            where: whereCondition,
            orderBy: { createdAt: 'desc' }
        });

        // Si no hay nada, el enriquecimiento no se rompe
        const enrichedContent = await Promise.all(
            content.map(movie => enrichMovieData(movie))
        );

        res.json(enrichedContent);
    } catch (error) {
        console.error("Error en /api/movies:", error);
        res.status(500).json({ error: "Error al cargar datos de Neon" });
    }
});

// ==========================================
//   AUTENTICACIÓN (LOGIN & REGISTER)
// ==========================================

async function sendEmail(to, subject, htmlContent) {
    try {
        await axios.post('https://api.brevo.com/v3/smtp/email', {
            sender: { name: 'MovieWind', email: 'moviewindsupport@gmail.com' },
            to: [{ email: to }],
            subject: subject,
            htmlContent: htmlContent
        }, {
            headers: { 'api-key': process.env.BREVO_API_KEY, 'Content-Type': 'application/json' }
        });
    } catch (error) {
        console.error("Error enviando email:", error.response?.data || error.message);
    }
}

app.post('/api/auth/send-otp', async (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: "Email requerido" });
    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const normalizedEmail = email.toLowerCase().trim();
    try {
        await prisma.user.upsert({
            where: { email: normalizedEmail },
            update: { pin: otp, pinExpiresAt: new Date(Date.now() + 15 * 60000) },
            create: { email: normalizedEmail, pin: otp, pinExpiresAt: new Date(Date.now() + 15 * 60000), name: "Usuario" }
        });
        await sendEmail(normalizedEmail, "Tu código de acceso - MovieWind", `<h1>Código: ${otp}</h1>`);
        res.json({ success: true });
    } catch (error) { res.status(500).json({ error: "Error de servidor" }); }
});

app.post('/api/auth/verify-otp', async (req, res) => {
    const { email, code } = req.body;
    try {
        const user = await prisma.user.findUnique({ where: { email: email.toLowerCase().trim() } });
        if (user && user.pin === code && new Date() < user.pinExpiresAt) {
            const updated = await prisma.user.update({
                where: { email: email.toLowerCase().trim() },
                data: { pin: null, pinExpiresAt: null, isVerified: true }
            });
            res.json(updated);
        } else { res.status(401).json({ error: "Código inválido" }); }
    } catch (error) { res.status(500).json({ error: "Error al verificar" }); }
});

app.post('/api/auth/register', async (req, res) => {
    const { email, name, plan } = req.body;
    try {
        const user = await prisma.user.upsert({
            where: { email: email.toLowerCase().trim() },
            update: { name, plan: plan || "basico" },
            create: { email: email.toLowerCase().trim(), name, plan: plan || "basico", isVerified: true }
        });
        res.status(201).json(user);
    } catch (error) { res.status(500).json({ error: "Error en registro" }); }
});

// ==========================================
//   GESTIÓN DE USUARIOS
// ==========================================

app.get('/api/users', async (req, res) => {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: "Email requerido" });
    try {
        const user = await prisma.user.findUnique({ where: { email: email.toLowerCase().trim() } });
        res.json(user);
    } catch (error) { res.status(500).json({ error: "Error" }); }
});

app.put("/api/users/:id", async (req, res) => {
    const { id } = req.params;
    const { name, profilePic, plan } = req.body;
    try {
        const userUpdated = await prisma.user.update({
            where: { id: id.includes('-') ? id : parseInt(id) }, // Maneja UUID o Int
            data: { name, profilePic, plan },
        });
        res.json(userUpdated);
    } catch (error) { res.status(500).json({ error: "Error al actualizar" }); }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Servidor corriendo en puerto ${PORT}`);
});