import 'dotenv/config';
import express from 'express';
import cors from 'cors';

// --- IMPORTACIÓN DE RUTAS (Ahora con sintaxis import) ---
// Nota: Es importante incluir la extensión .js al final de los archivos locales
import movieRoutes from './routes/movie_routes.js';
import authRoutes from './routes/auth_routes.js';
import adminRoutes from './routes/admin_routes.js';
import * as authController from './controllers/auth_controller.js';
import watchlistRoutes from './routes/watchlist_routes.js';

const app = express();

// 1. CONFIGURACIÓN DE MIDDLEWARES
app.use(cors({
    origin: '*',
    methods: '*',
    allowedHeaders: '*',
    exposedHeaders: '*'
}));

app.use(express.json());

// 2. DEFINICIÓN DE PUNTOS DE ENTRADA (ENDPOINTS)
app.use('/api/movies', movieRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/watchlist', watchlistRoutes);

app.get('/api/users', authController.getUserByEmail);

// 3. RUTA DE SALUD
app.get('/', (req, res) => {
    res.send('Servidor MOVIEWIND Activo 🚀');
});

// 4. ARRANQUE DEL SERVIDOR
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Servidor MOVIEWIND corriendo en puerto ${PORT}`);
});