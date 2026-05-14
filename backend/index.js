require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();

// --- IMPORTACIÓN DE RUTAS ---
const movieRoutes = require('./routes/movie_routes');
const authRoutes = require('./routes/auth_routes');
const adminRoutes = require('./routes/admin_routes');
const watchlistRoutes = require('./routes/watchlist_routes');
const scraperRoutes = require('./routes/scraper_routes');
const streamRoutes = require('./routes/stream_routes');
const { getStreamLink, getStatus } = require('./controllers/stream_controller');
const { startWorker, stopWorker } = require('./services/stream_worker');

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
  allowedHeaders: ['Content-Type', 'Accept', 'Authorization']
}));

app.use(express.json());
app.use(express.static('public'));

// 2. RUTAS
app.use('/api/movies', movieRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/watchlist', watchlistRoutes);
app.use('/api', scraperRoutes);
app.use('/api', streamRoutes);

app.get('/api/stream/link', getStreamLink);
app.get('/api/stream/status', getStatus);

// Health check rápido en raíz (útil para monitoreo externo)
app.get('/health', async (req, res) => {
  try {
    const { getWorkerHealth } = require('./services/stream_worker');
    const health = await getWorkerHealth();
    res.json({ ok: true, ...health });
  } catch (error) {
    res.status(503).json({ ok: false, error: error.message });
  }
});

app.get('/', (req, res) => {
  res.send('Servidor MOVIEWIND Activo 🚀');
});

// 3. ARRANQUE
const PORT = process.env.PORT || 8080;
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Servidor en puerto ${PORT}`);
  console.log(`📊 Health: http://localhost:${PORT}/health`);
  console.log(`📊 Health (detallado): http://localhost:${PORT}/api/stream/health`);
  startWorker();
});

server.timeout = 120000;

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('⚠️ Señal SIGTERM recibida, cerrando gracefully...');
  stopWorker();
  server.close(() => {
    console.log('✅ Servidor cerrado');
    process.exit(0);
  });
});

process.on('unhandledRejection', (error) => {
  console.error('❌ Unhandled Rejection:', error);
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  // No cerramos el proceso, solo logueamos
});