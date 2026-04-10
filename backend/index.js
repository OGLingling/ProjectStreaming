// index.js
require('dotenv').config(); // Carga variables de entorno (Railway lo hace solo, pero sirve para local)
const express = require('express');
const cors = require('cors');

// --- IMPORTACIÓN DE RUTAS ---
const movieRoutes = require('./routes/movie_routes');
const authRoutes = require('./routes/auth_routes');
const adminRoutes = require('./routes/admin_routes');

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
// Aquí conectamos los prefijos de las URLs con tus archivos de rutas
app.use('/api/movies', movieRoutes);  // Maneja películas y proxy
app.use('/api/auth', authRoutes);    // Maneja OTP, Registro y Perfil
app.use('/api/admin', adminRoutes);  // Maneja supervisión de admin

app.get('/api/users', authController.getUserByEmail);

// 3. RUTA DE SALUD (Opcional, útil para ver si el server vive)
app.get('/', (req, res) => {
    res.send('Servidor MOVIEWIND Activo 🚀');
});

// 4. ARRANQUE DEL SERVIDOR
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Servidor MOVIEWIND corriendo en puerto ${PORT}`);
});