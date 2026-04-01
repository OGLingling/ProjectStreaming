const express = require('express');
const cors = require('cors');
const axios = require('axios'); // Nueva dependencia
const { PrismaClient } = require('@prisma/client');

const app = express();
const prisma = new PrismaClient();

// --- CONFIGURACIÓN TMDB ---
// Regístrate en themoviedb.org para obtener una API KEY gratuita
const TMDB_API_KEY = 'TU_API_KEY_AQUI'; 
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    credentials: true
}));

app.use(express.json());

// --- FUNCIÓN PARA ENRIQUECER DATOS DESDE TMDB ---
async function enrichMovieData(movie) {
    if (!movie.imdbId) return movie;

    try {
        const findUrl = `${TMDB_BASE_URL}/find/${movie.imdbId}?api_key=${TMDB_API_KEY}&external_source=imdb_id&language=es-ES`;
        const response = await axios.get(findUrl);
        
        // TMDB devuelve resultados en diferentes listas según el tipo
        const data = response.data.movie_results[0] || response.data.tv_results[0];

        if (data) {
            return {
                ...movie,
                title: data.title || data.name,
                description: data.overview || movie.description,
                imageUrl: `https://image.tmdb.org/t/p/w500${data.poster_path}`,
                backdropUrl: `https://image.tmdb.org/t/p/original${data.backdrop_path}`,
                rating: parseFloat(data.vote_average.toFixed(1)),
            };
        }
    } catch (error) {
        console.error(`Error en TMDB para ${movie.imdbId}:`, error.message);
    }
    return movie;
}

// --- RUTAS DE CORREO (Brevo) ---
async function sendEmail(to, subject, htmlContent) {
    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: {
            'accept': 'application/json',
            'api-key': process.env.BREVO_API_KEY,
            'content-type': 'application/json'
        },
        body: JSON.stringify({
            sender: { name: 'MovieWind', email: 'moviewindsupport@gmail.com' },
            to: [{ email: to }],
            subject: subject,
            htmlContent: htmlContent
        })
    });
    if (!response.ok) throw new Error('Error al enviar email');
    return response.json();
}

// --- RUTAS DE AUTENTICACIÓN ---
app.post('/api/auth/send-otp', async (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: "Email requerido" });
    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const normalizedEmail = email.toLowerCase().trim();

    try {
        await prisma.user.upsert({
            where: { email: normalizedEmail },
            update: { pin: otp, pinExpiresAt: new Date(Date.now() + 15 * 60000) },
            create: { email: normalizedEmail, pin: otp, pinExpiresAt: new Date(Date.now() + 15 * 60000), name: "Usuario Nuevo" }
        });
        await sendEmail(normalizedEmail, "Tu código MovieWind", `<h1>Tu código es: ${otp}</h1>`);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
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
    } catch (e) { res.status(500).json({ error: "Error" }); }
});

// --- RUTA DE PELÍCULAS (DINÁMICA) ---
app.get('/api/movies', async (req, res) => {
    const { type } = req.query;
    try {
        const moviesDB = await prisma.movie.findMany({
            where: type ? { type: String(type) } : {},
            orderBy: { releaseDate: 'desc' }
        });

        // Llamamos a TMDB para cada película guardada en nuestra DB
        const enriched = await Promise.all(moviesDB.map(m => enrichMovieData(m)));
        res.json(enriched);
    } catch (error) {
        res.status(500).json({ error: "Error al cargar contenido" });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => console.log(`Servidor en puerto ${PORT}`));