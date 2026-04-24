require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();

// --- IMPORTACIÓN DE RUTAS ---
const movieRoutes = require('./routes/movie_routes');
const authRoutes = require('./routes/auth_routes');
const adminRoutes = require('./routes/admin_routes');
const authController = require('./controllers/auth_controller');
const watchlistRoutes = require('./routes/watchlist_routes');
const scraperRoutes = require('./routes/scraper_routes');

// 1. CONFIGURACIÓN DE MIDDLEWARES
const allowedOrigins = [
    'https://oglingling.github.io',
    'http://localhost:3000',
    'http://localhost:5173'
];

app.use(cors({
    origin: (origin, callback) => {
        if (!origin || allowedOrigins.includes(origin)) {
            return callback(null, true);
        }
        return callback(new Error('Origen no permitido por CORS'));
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());
app.use(express.static('public'));

// 2. DEFINICIÓN DE PUNTOS DE ENTRADA (ENDPOINTS)
// Aquí conectamos los prefijos de las URLs con tus archivos de rutas
app.use('/api/movies', movieRoutes);  // Maneja películas y proxy
app.use('/api/auth', authRoutes);    // Maneja OTP, Registro y Perfil
app.use('/api/admin', adminRoutes);  // Maneja supervisión de admin
app.use('/api/watchlist', watchlistRoutes); // Maneja watchlist
app.use('/api', scraperRoutes);

app.get('/api/users', authController.getUserByEmail);

// 3. RUTA DE SALUD (Opcional, útil para ver si el server vive)
app.get('/', (req, res) => {
    res.send('Servidor MOVIEWIND Activo 🚀');
});

// Ruta de Health Check crítica para Render
app.get('/health', (req, res) => res.status(200).send('OK'));

// Middleware para atrapar 404
app.use((req, res) => { 
    console.log("❌ 404 Capturado en la ruta:", req.originalUrl); 
    res.status(404).send("Not Found - MovieWind API"); 
});

// 4. ARRANQUE DEL SERVIDOR
const PORT = process.env.PORT || 8080;
const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`Servidor activo en puerto ${PORT}`);
    console.log("✅ Ruta de scraping cargada correctamente en /api/extract");
});
server.timeout = 120000;
