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
const streamRoutes = require('./routes/stream_routes');
const { getStreamLink, getStatus, forceRefresh, runWorkerCycle } = require('./controllers/stream_controller');
const { startWorker } = require('./services/stream_worker');

// 1. MIDDLEWARES
const allowedOrigins = [
  'https://oglingling.github.io',
  'http://localhost:3000',
  'http://localhost:5173'
];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error('Origen no permitido por CORS'));
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Accept', 'Authorization']
}));

app.use(express.json());
app.use(express.static('public'));

// ─── MIDDLEWARE DE AUTENTICACIÓN ADMIN ────────────────────────────────────────
// Protege endpoints que pueden disparar scraping arbitrario.
// Agrega ADMIN_KEY en tus variables de entorno en Render.
const adminAuth = (req, res, next) => {
  const key = req.headers['x-admin-key'] || req.query.key;
  if (!process.env.ADMIN_KEY) {
    // Si no está configurada la clave, bloquea en producción
    console.warn('[admin] ⚠ ADMIN_KEY no configurada — endpoint bloqueado');
    return res.status(503).json({ error: 'Endpoint admin no configurado' });
  }
  if (key !== process.env.ADMIN_KEY) {
    return res.status(401).json({ error: 'No autorizado' });
  }
  next();
};

// 2. ENDPOINTS
app.use('/api/movies', movieRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/watchlist', watchlistRoutes);

// Stream — endpoint principal que usa Flutter
app.get('/api/stream/link', getStreamLink);
app.get('/api/stream/status', getStatus);

// Endpoints admin — protegidos con ADMIN_KEY
app.post('/api/stream/force-refresh', adminAuth, forceRefresh);
app.get('/api/stream/force-refresh', adminAuth, forceRefresh);
app.post('/api/stream/worker/run', adminAuth, runWorkerCycle);

// Rutas legacy del scraper y stream proxy
app.use('/api', scraperRoutes);
app.use('/api', streamRoutes);

app.get('/api/users', authController.getUserByEmail);

// 3. RUTAS DE SALUD
app.get('/', (req, res) => res.send('Servidor MOVIEWIND Activo 🚀'));
app.get('/health', (req, res) => res.status(200).send('OK'));

// 404
app.use((req, res) => {
  console.log('❌ 404:', req.originalUrl);
  res.status(404).send('Not Found - MovieWind API');
});

// 4. ARRANQUE
const PORT = process.env.PORT || 8080;
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor activo en puerto ${PORT}`);
  console.log('✅ Ruta de scraping cargada correctamente en /api/extract');
  startWorker();
});

server.timeout = 120000;

process.on('SIGTERM', () => {
  const { stopWorker } = require('./services/stream_worker');
  stopWorker();
  process.exit(0);
});