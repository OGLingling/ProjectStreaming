const express = require('express');
const cors = require('cors');
const axios = require('axios'); // <--- Agregado para TMDB
const { PrismaClient } = require('@prisma/client');

const app = express();
const prisma = new PrismaClient();

// --- CONFIGURACIÓN TMDB ---
// Regístrate en themoviedb.org para obtener tu clave gratuita
const TMDB_API_KEY = 'TU_API_KEY_AQUI'; 
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

// CONFIGURACION DE CORS PARA FLUTTER (WEB Y MOVIL)
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    credentials: true
}));

app.use(express.json());

// --- FUNCIÓN PARA ENRIQUECER DATOS DESDE TMDB (AXIOS) ---
async function enrichMovieData(movie) {
    if (!movie.imdbId) return movie;

    try {
        const findUrl = `${TMDB_BASE_URL}/find/${movie.imdbId}?api_key=${TMDB_API_KEY}&external_source=imdb_id&language=es-ES`;
        const response = await axios.get(findUrl);
        
        // TMDB devuelve resultados en diferentes listas según sea película o serie
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
        console.error(`Error en TMDB para ID ${movie.imdbId}:`, error.message);
    }
    return movie; // Si falla la API externa, devolvemos los datos base de la DB
}

// --- FUNCION PARA ENVIAR EMAIL CON BREVO API (NO SMTP) ---
async function sendEmail(to, subject, htmlContent) {
    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: {
            'accept': 'application/json',
            'api-key': process.env.BREVO_API_KEY,
            'content-type': 'application/json'
        },
        body: JSON.stringify({
            sender: {
                name: 'MovieWind',
                email: 'moviewindsupport@gmail.com'
            },
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

// --- RUTAS DE AUTENTICACION (OTP) ---

app.post('/api/auth/send-otp', async (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: "Email requerido" });

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const normalizedEmail = email.toLowerCase().trim();

    try {
        await prisma.user.upsert({
            where: { email: normalizedEmail },
            update: {
                pin: otp,
                pinExpiresAt: new Date(Date.now() + 15 * 60000)
            },
            create: {
                email: normalizedEmail,
                pin: otp,
                pinExpiresAt: new Date(Date.now() + 15 * 60000),
                name: "Usuario Nuevo"
            }
        });

        await sendEmail(
            normalizedEmail,
            "Tu codigo de acceso - MovieWind",
            `
                <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 500px; margin: 0 auto; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border-radius: 16px; overflow: hidden;">
                    <div style="background: linear-gradient(90deg, #E50914 0%, #ff6b6b 100%); padding: 30px; text-align: center;">
                        <h1 style="color: white; margin: 0; font-size: 32px; font-weight: bold;">MovieWind</h1>
                    </div>
                    <div style="padding: 40px 30px; text-align: center;">
                        <h2 style="color: #ffffff; margin: 0 0 10px 0;">Codigo de verificacion</h2>
                        <div style="background: linear-gradient(135deg, #E50914 0%, #b81d24 100%); padding: 25px 40px; border-radius: 12px; display: inline-block;">
                            <span style="color: white; font-size: 42px; font-weight: bold; letter-spacing: 12px;">${otp}</span>
                        </div>
                        <p style="color: #888; margin-top: 30px;">Este codigo expira en 15 minutos</p>
                    </div>
                </div>
            `
        );

        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: "Error al enviar el correo" });
    }
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
        } else {
            res.status(401).json({ error: "Codigo incorrecto o expirado" });
        }
    } catch (error) {
        res.status(500).json({ error: "Error al verificar codigo" });
    }
});

app.get('/api/users', async (req, res) => {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: "Email requerido" });

    try {
        const user = await prisma.user.findUnique({
            where: { email: String(email).toLowerCase().trim() }
        });
        res.json(user || null);
    } catch (error) {
        res.status(500).json({ error: "Error interno al buscar usuario" });
    }
});

app.post('/api/auth/register', async (req, res) => {
    const { email, name, password, plan } = req.body;
    const normalizedEmail = email.toLowerCase().trim();

    let planNormalizado = "basico";
    if (plan) {
        planNormalizado = plan.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }

    try {
        const user = await prisma.user.upsert({
            where: { email: normalizedEmail },
            update: { name, plan: planNormalizado },
            create: {
                email: normalizedEmail,
                name,
                password: password || "123456",
                plan: planNormalizado,
                isVerified: true,
            }
        });

        await sendEmail(normalizedEmail, "Bienvenido a MovieWind!", `<h2>Bienvenido, ${name}!</h2>`);
        res.status(201).json(user);
    } catch (error) {
        res.status(500).json({ error: "No se pudo completar el registro" });
    }
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
    } catch (error) {
        res.status(500).json({ error: "Error al actualizar usuario" });
    }
});

// --- OBTENER PELICULAS (MODIFICADO CON AXIOS Y TMDB) ---
app.get(['/api/movies', '/movies'], async (req, res) => {
    let { type } = req.query;
    
    console.log("Petición recibida. Filtro original:", type);

    try {
        let whereCondition = {};
        
        if (type) {
            // Normalizamos el tipo: quitamos espacios y pasamos a minúsculas
            // Esto evita que "Serie" vs "serie" falle.
            const normalizedType = type.toLowerCase().trim();
            whereCondition = { type: normalizedType };
        }

        // 1. Buscamos en nuestra base de datos (Railway)
        const content = await prisma.movie.findMany({
            where: whereCondition,
            orderBy: { releaseDate: 'desc' }
        });

        console.log(`Encontrados en DB: ${content.length} registros.`);

        if (content.length === 0) {
            return res.json([]); // Si no hay nada, enviamos lista vacía sin error
        }

        // 2. Por cada película, pedimos los datos reales a TMDB usando su imdbId
        const enrichedContent = await Promise.all(
            content.map(movie => enrichMovieData(movie))
        );

        res.json(enrichedContent);
    } catch (error) {
        console.error("Error crítico cargando películas:", error);
        res.status(500).json({ error: "Error al cargar contenido", details: error.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Servidor corriendo en el puerto ${PORT}`);
});