const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');
const nodemailer = require('nodemailer');

const app = express();
const prisma = new PrismaClient();

// ✅ CORS CONFIGURADO PARA FLUTTER WEB
app.use(cors({
    origin: 'https://moviewind.netlify.app',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
}));

app.use(express.json());

// --- CONFIGURACIÓN DE NODEMAILER ---
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: 'moviewindsupport@gmail.com', 
        pass: 'vhchkvifdckabnyc' 
    }
});

// --- RUTAS DE AUTENTICACIÓN (OTP) ---

// 1. Enviar código de 4 dígitos
app.post('/api/auth/send-otp', async (req, res) => {
    const { email } = req.body;
    const otp = Math.floor(1000 + Math.random() * 9000).toString();

    try {
        await prisma.user.upsert({
            where: { email },
            update: { 
                pin: otp, 
                pinExpiresAt: new Date(Date.now() + 15 * 60000) 
            },
            create: { 
                email, 
                pin: otp, 
                pinExpiresAt: new Date(Date.now() + 15 * 60000),
                name: "Usuario Nuevo"
            }
        });

        await transporter.sendMail({
            from: '"MovieWind" <moviewindsupport@gmail.com>',
            to: email,
            subject: "Tu código de acceso - MovieWind",
            html: `
                <div style="font-family: Arial, sans-serif; line-height: 1.6;">
                    <h2>Bienvenido a MovieWind</h2>
                    <p>Tu código de acceso es: <strong style="font-size: 24px; color: #E50914;">${otp}</strong></p>
                    <p>Expira en 15 min.</p>
                </div>
            `
        });

        res.json({ success: true });
    } catch (error) {
        console.error("❌ Error en send-otp:", error);
        res.status(500).json({ error: "Error al enviar el código" });
    }
});

// 2. Verificar código
app.post('/api/auth/verify-otp', async (req, res) => {
    const { email, code } = req.body;
    try {
        const user = await prisma.user.findUnique({ where: { email } });

        if (user && user.pin === code && new Date() < user.pinExpiresAt) {
            const updatedUser = await prisma.user.update({
                where: { email },
                data: { pin: null, pinExpiresAt: null, isVerified: true }
            });
            res.json(updatedUser);
        } else {
            res.status(401).json({ error: "Código incorrecto o expirado" });
        }
    } catch (error) {
        res.status(500).json({ error: "Error al verificar" });
    }
});

// --- RUTAS DE USUARIO ---

// ✅ RUTA NUEVA: Obtener usuario por email (Necesaria para tu ApiService de Flutter)
app.get('/api/users', async (req, res) => {
    const { email } = req.query;
    try {
        const user = await prisma.user.findUnique({
            where: { email: String(email) }
        });
        if (user) {
            res.json(user);
        } else {
            res.status(404).json({ error: "Usuario no encontrado" });
        }
    } catch (error) {
        res.status(500).json({ error: "Error al buscar usuario" });
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

app.post('/api/auth/register', async (req, res) => {
    const { email, name, password, plan } = req.body; 

    let planNormalizado = "basico";
    if (plan) {
        planNormalizado = plan.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }

    try {
        const user = await prisma.user.upsert({
            where: { email },
            update: { name, plan: planNormalizado }, 
            create: {
                email,
                name,
                password: password || "123456",
                plan: planNormalizado,
                isVerified: true, 
            }
        });

        await transporter.sendMail({
            from: '"MovieWind" <moviewindsupport@gmail.com>',
            to: email,
            subject: "¡Bienvenido a MovieWind!",
            html: `<h1>¡Hola, ${name}!</h1><p>Tu cuenta ha sido creada con el plan: ${planNormalizado.toUpperCase()}</p>`
        });

        res.status(201).json(user); 
    } catch (error) {
        console.error("Error en registro:", error);
        res.status(500).json({ error: "No se pudo completar el registro" });
    }
});

// --- RUTAS DE PELÍCULAS ---

app.get('/api/movies', async (req, res) => {
    const { type } = req.query; 
    try {
        const content = await prisma.movie.findMany({
            where: type ? { type: String(type) } : {},
            orderBy: { releaseDate: 'desc' }
        });
        res.json(content);
    } catch (error) {
        res.status(500).json({ error: "Error en la base de datos" });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Servidor corriendo en el puerto ${PORT}`);
});