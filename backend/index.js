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
const VideoScraper = require('./services/scraper_service');

// 1. CONFIGURACIÓN DE MIDDLEWARES
app.use(cors({
    origin: 'https://oglingling.github.io',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
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
app.use('/api/extract', scraperRoutes);

// Ruta directa para extracción de video
app.get('/api/extract', async (req, res) => {
  const { url } = req.query;
  
  if (!url) {
    return res.status(400).json({
      success: false,
      error: "Falta el parámetro 'url'. Ejemplo: /api/extract?url=https://ejemplo.com"
    });
  }
  
  try {
    console.log(`🔍 Extrayendo video desde: ${url}`);
    const streamUrl = await VideoScraper.extractStreamUrl(url);
    
    if (streamUrl) {
      return res.status(200).json({
        success: true,
        streamUrl: streamUrl
      });
    }
    
    return res.status(404).json({
      success: false,
      error: "No se encontró ningún stream de video"
    });
    
  } catch (error) {
    console.error('❌ Error en extracción:', error.message);
    return res.status(500).json({
      success: false,
      error: "Error interno del servidor durante la extracción",
      details: error.message
    });
  }
});

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