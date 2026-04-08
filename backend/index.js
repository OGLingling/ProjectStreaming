const express = require('express');
const cors = require('cors');
const axios = require('axios');
const { PrismaClient } = require('@prisma/client');

const app = express();
const prisma = new PrismaClient();

// --- CONFIGURACIÓN TMDB ---
const TMDB_API_KEY = 'd8a00b94f5c00821e497b569fec9a61f'; 
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

// CONFIGURACION DE CORS
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    credentials: true
}));

app.use(express.json());

// ==========================================
//   LÓGICA DE PELÍCULAS (VERSIÓN ULTRA-FAST)
// ==========================================

async function enrichMovieData(movie) {
    const identifier = movie.tmdbId || movie.imdbId;
    if (!identifier) return movie;

    try {
        let apiUrl;
        if (movie.tmdbId) {
            const path = movie.type === 'tv' ? 'tv' : 'movie';
            // Usamos append_to_response para traer videos (trailers) de una vez
            apiUrl = `${TMDB_BASE_URL}/${path}/${movie.tmdbId}?api_key=${TMDB_API_KEY}&language=es-ES&append_to_response=videos`;
        } else {
            apiUrl = `${TMDB_BASE_URL}/find/${movie.imdbId}?api_key=${TMDB_API_KEY}&external_source=imdb_id&language=es-ES`;
        }

        // Añadimos un timeout de 2 segundos para que la API no se quede colgada
        const response = await axios.get(apiUrl, { timeout: 2000 });
        
        let data = movie.tmdbId 
            ? response.data 
            : (response.data.movie_results[0] || response.data.tv_results[0]);

        if (data) {
            // Extraer trailer si existe
            const trailer = data.videos?.results?.find(v => v.type === 'Trailer' && v.site === 'YouTube');

            return {
                ...movie,
                title: data.title || data.name || movie.title,
                description: data.overview || movie.description,
                imageUrl: data.poster_path ? `https://image.tmdb.org/t/p/w500${data.poster_path}` : movie.imageUrl,
                backdropUrl: data.backdrop_path ? `https://image.tmdb.org/t/p/original${data.backdrop_path}` : movie.backdropUrl,
                rating: data.vote_average ? parseFloat(data.vote_average.toFixed(1)) : (movie.rating || 0.0),
                trailerUrl: trailer ? `https://www.youtube.com/watch?v=${trailer.key}` : null,
            };
        }
    } catch (error) {
        // Log ligero para no saturar la consola de Railway
        console.error(`[TMDB Skip] ID ${identifier}: ${error.code || 'Timeout/Error'}`);
    }
    return movie; // Siempre devolvemos el original si falla el enriquecimiento
}

app.get(['/api/movies', '/movies'], async (req, res) => {
    try {
        const { type } = req.query;
        let whereCondition = {};
        
        if (type) {
            const normalizedType = type.toLowerCase().trim().replace('s', '');
            whereCondition = { type: { contains: normalizedType, mode: 'insensitive' } };
        }

        // 1. Obtener de Prisma
        const content = await prisma.movie.findMany({
            where: whereCondition,
            orderBy: { createdAt: 'desc' },
            take: 20 // Limitamos a 20 para asegurar que la carga sea instantánea
        });

        if (content.length === 0) {
            return res.json([]); // Si no hay nada en la DB, enviamos lista vacía rápido
        }

        // 2. Enriquecer (Si TMDB falla, enrichMovieData devuelve el objeto de la DB original)
        const enrichedContent = await Promise.all(
            content.map(movie => enrichMovieData(movie))
        );

        res.json(enrichedContent);
    } catch (error) {
        console.error("Critical Error en /api/movies:", error);
        res.status(500).json({ error: "Error interno del servidor" });
    }
});

// ==========================================
//   LÓGICA DE AUTENTICACIÓN (SIN TOCAR)
// ==========================================

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
    if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || 'Error al enviar email');
    }
    return response.json();
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
            create: { email: normalizedEmail, pin: otp, pinExpiresAt: new Date(Date.now() + 15 * 60000), name: "Usuario Nuevo" }
        });
        await sendEmail(normalizedEmail, "Tu codigo de acceso - MovieWind", `
            <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 500px; margin: 0 auto; background: #1a1a2e; border-radius: 16px; overflow: hidden; padding: 20px;">
                <h1 style="color: #E50914; text-align: center;">MovieWind</h1>
                <h2 style="color: white; text-align: center;">Codigo: ${otp}</h2>
            </div>
        `);
        res.json({ success: true });
    } catch (error) { res.status(500).json({ error: "Error al enviar el correo" }); }
});

app.post('/api/auth/verify-otp', async (req, res) => {
    const { email, code } = req.body;
    const normalizedEmail = email.toLowerCase().trim();
    try {
        const user = await prisma.user.findUnique({ where: { email: normalizedEmail } });
        if (user && user.pin === code && new Date() < user.pinExpiresAt) {
            const updatedUser = await prisma.user.update({
                where: { email: normalizedEmail },
                data: { pin: null, pinExpiresAt: null, isVerified: true }
            });
            res.json(updatedUser);
        } else { res.status(401).json({ error: "Codigo incorrecto o expirado" }); }
    } catch (error) { res.status(500).json({ error: "Error al verificar" }); }
});

app.get('/api/users', async (req, res) => {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: "Email requerido" });
    try {
        const user = await prisma.user.findUnique({ where: { email: String(email).toLowerCase().trim() } });
        res.json(user || null);
    } catch (error) { res.status(500).json({ error: "Error al buscar usuario" }); }
});

app.post('/api/auth/register', async (req, res) => {
    const { email, name, password, plan } = req.body;
    const normalizedEmail = email.toLowerCase().trim();
    let planNormalizado = plan ? plan.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "") : "basico";
    try {
        const user = await prisma.user.upsert({
            where: { email: normalizedEmail },
            update: { name, plan: planNormalizado },
            create: { email: normalizedEmail, name, password: password || "123456", plan: planNormalizado, isVerified: true }
        });
        await sendEmail(normalizedEmail, "Bienvenido a MovieWind!", `<h2>Bienvenido, ${name}!</h2>`);
        res.status(201).json(user);
    } catch (error) { res.status(500).json({ error: "Error en registro" }); }
});

app.put("/api/users/:id", async (req, res) => {
    const { id } = req.params;
    const { name, profilePic, plan } = req.body;
    try {
        const userUpdated = await prisma.user.update({
            where: { id: id },
            data: { name, profilePic, plan },
        });
        res.json(userUpdated);
    } catch (error) { res.status(500).json({ error: "Error al actualizar" }); }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Servidor MOVIEWIND corriendo en puerto ${PORT}`);
});