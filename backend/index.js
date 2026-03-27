const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');

const app = express();
const prisma = new PrismaClient();

// CONFIGURACION DE CORS PARA FLUTTER (WEB Y MOVIL)
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    credentials: true
}));

app.use(express.json());

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

// 1. Enviar codigo de 4 digitos (Login/Registro inicial)
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
                <div style="font-family: Arial, sans-serif; border: 1px solid #ddd; padding: 20px; border-radius: 10px;">
                    <h2 style="color: #E50914;">Bienvenido a MovieWind</h2>
                    <p>Usa el siguiente codigo para ingresar a tu cuenta:</p>
                    <div style="background: #f4f4f4; padding: 15px; text-align: center; font-size: 30px; font-weight: bold; letter-spacing: 5px;">
                        ${otp}
                    </div>
                    <p style="color: #777; font-size: 12px;">Este codigo expira en 15 minutos.</p>
                </div>
            `
        );

        console.log("Email OTP enviado a:", normalizedEmail);
        res.json({ success: true });
    } catch (error) {
        console.error("Error detallado en send-otp:", error);
        res.status(500).json({ error: "Error al enviar el correo", details: error.message });
    }
});

// 2. Verificar codigo y devolver datos del usuario
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
        console.error("Error en verify-otp:", error);
        res.status(500).json({ error: "Error al verificar codigo" });
    }
});

// --- RUTA DE BUSQUEDA DE USUARIOS ---
app.get('/api/users', async (req, res) => {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: "Email requerido" });

    try {
        const user = await prisma.user.findUnique({
            where: { email: String(email).toLowerCase().trim() }
        });
        res.json(user || null);
    } catch (error) {
        console.error("Error en GET /api/users:", error);
        res.status(500).json({ error: "Error interno al buscar usuario" });
    }
});

// --- RUTA DE REGISTRO FINAL ---
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

        await sendEmail(
            normalizedEmail,
            "Bienvenido a MovieWind!",
            `<h1>Hola, ${name}!</h1><p>Tu cuenta ha sido activada con el plan: <strong>${planNormalizado.toUpperCase()}</strong></p>`
        );

        res.status(201).json(user);
    } catch (error) {
        console.error("Error en registro:", error);
        res.status(500).json({ error: "No se pudo completar el registro" });
    }
});

// --- ACTUALIZAR USUARIO ---
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

// --- OBTENER PELICULAS ---
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
    console.log(`Servidor corriendo en el puerto ${PORT}`);
});
