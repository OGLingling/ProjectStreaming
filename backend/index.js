const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');
const nodemailer = require('nodemailer');

const app = express();
const prisma = new PrismaClient();

// ✅ CONFIGURACIÓN DE CORS PARA FLUTTER (WEB Y MÓVIL)
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
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

// 1. Enviar código de 4 dígitos (Login/Registro inicial)
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

        await transporter.sendMail({
            from: '"MovieWind" <moviewindsupport@gmail.com>',
            to: normalizedEmail,
            subject: "Tu código de acceso - MovieWind",
            html: `
                <div style="font-family: Arial, sans-serif; border: 1px solid #ddd; padding: 20px; border-radius: 10px;">
                    <h2 style="color: #E50914;">Bienvenido a MovieWind</h2>
                    <p>Usa el siguiente código para ingresar a tu cuenta:</p>
                    <div style="background: #f4f4f4; padding: 15px; text-align: center; font-size: 30px; font-weight: bold; letter-spacing: 5px;">
                        ${otp}
                    </div>
                    <p style="color: #777; font-size: 12px;">Este código expira en 15 minutos.</p>
                </div>
            `
        });

        res.json({ success: true });
    } catch (error) {
        console.error("❌ Error en send-otp:", error);
        res.status(500).json({ error: "Error al enviar el correo" });
    }
});

// 2. Verificar código y devolver datos del usuario
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
            res.status(401).json({ error: "Código incorrecto o expirado" });
        }
    } catch (error) {
        console.error("❌ Error en verify-otp:", error);
        res.status(500).json({ error: "Error al verificar código" });
    }
});

// --- RUTAS DE USUARIO ---

// ✅ RUTA CORREGIDA: Busca usuario por email (Evita el error 500)
app.get('/api/users', async (req, res) => {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: "Email requerido" });

    try {
        const user = await prisma.user.findUnique({
            where: { email: String(email).toLowerCase().trim() }
        });

        // Enviamos el objeto si existe, o null si no. 
        // No enviamos 404 para que Flutter no lo interprete como error de red.
        res.json(user || null); 
    } catch (error) {
        console.error("❌ Error en GET /api/users:", error);
        res.status(500).json({ error: "Error interno al buscar usuario" });
    }
});

// Registro final (Creación de perfil y plan)
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

        await transporter.sendMail({
            from: '"MovieWind" <moviewindsupport@gmail.com>',
            to: normalizedEmail,
            subject: "¡Bienvenido a MovieWind!",
            html: `<h1>¡Hola, ${name}!</h1><p>Tu cuenta ha sido activada con el plan: <strong>${planNormalizado.toUpperCase()}</strong></p>`
        });

        res.status(201).json(user); 
    } catch (error) {
        console.error("❌ Error en registro:", error);
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
        res.status(500).json({ error: "Error al cargar contenido" });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Servidor corriendo en el puerto ${PORT}`);
});