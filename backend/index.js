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
                <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 500px; margin: 0 auto; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border-radius: 16px; overflow: hidden;">
                    <!-- Header -->
                    <div style="background: linear-gradient(90deg, #E50914 0%, #ff6b6b 100%); padding: 30px; text-align: center;">
                        <h1 style="color: white; margin: 0; font-size: 32px; font-weight: bold; text-shadow: 2px 2px 4px rgba(0,0,0,0.3);">MovieWind</h1>
                        <p style="color: rgba(255,255,255,0.9); margin: 5px 0 0 0; font-size: 14px;">Tu portal de entretenimiento</p>
                    </div>
                    
                    <!-- Body -->
                    <div style="padding: 40px 30px; text-align: center;">
                        <h2 style="color: #ffffff; margin: 0 0 10px 0; font-size: 22px;">Codigo de verificacion</h2>
                        <p style="color: #a0a0a0; margin: 0 0 30px 0; font-size: 14px;">Ingresa este codigo para acceder a tu cuenta</p>
                        
                        <!-- Codigo OTP -->
                        <div style="background: linear-gradient(135deg, #E50914 0%, #b81d24 100%); padding: 25px 40px; border-radius: 12px; display: inline-block; box-shadow: 0 8px 25px rgba(229, 9, 20, 0.4);">
                            <span style="color: white; font-size: 42px; font-weight: bold; letter-spacing: 12px; font-family: 'Courier New', monospace;">${otp}</span>
                        </div>
                        
                        <p style="color: #888; font-size: 13px; margin-top: 30px;">Este codigo expira en <strong style="color: #E50914;">15 minutos</strong></p>
                    </div>
                    
                    <!-- Footer -->
                    <div style="background: rgba(0,0,0,0.3); padding: 20px; text-align: center; border-top: 1px solid rgba(255,255,255,0.1);">
                        <p style="color: #666; font-size: 12px; margin: 0;">Si no solicitaste este codigo, ignora este mensaje.</p>
                        <p style="color: #555; font-size: 11px; margin: 10px 0 0 0;">© 2026 MovieWind. Todos los derechos reservados.</p>
                    </div>
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
            `
                <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 500px; margin: 0 auto; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border-radius: 16px; overflow: hidden;">
                    <!-- Header -->
                    <div style="background: linear-gradient(90deg, #E50914 0%, #ff6b6b 100%); padding: 30px; text-align: center;">
                        <h1 style="color: white; margin: 0; font-size: 32px; font-weight: bold;">MovieWind</h1>
                    </div>
                    
                    <!-- Body -->
                    <div style="padding: 40px 30px; text-align: center;">
                        <h2 style="color: #ffffff; margin: 0 0 20px 0; font-size: 26px;">Bienvenido, ${name}!</h2>
                        <p style="color: #a0a0a0; margin: 0 0 30px 0; font-size: 16px;">Tu cuenta ha sido creada exitosamente</p>
                        
                        <!-- Plan -->
                        <div style="background: rgba(229, 9, 20, 0.15); border: 2px solid #E50914; padding: 20px; border-radius: 12px; margin-bottom: 25px;">
                            <p style="color: #888; margin: 0 0 5px 0; font-size: 12px; text-transform: uppercase;">Tu plan actual</p>
                            <p style="color: #E50914; margin: 0; font-size: 28px; font-weight: bold; text-transform: uppercase;">${planNormalizado}</p>
                        </div>
                        
                        <p style="color: #a0a0a0; font-size: 14px; line-height: 1.6;">Ya puedes disfrutar de miles de peliculas y series. Abre la app y comienza a explorar!</p>
                    </div>
                    
                    <!-- Footer -->
                    <div style="background: rgba(0,0,0,0.3); padding: 20px; text-align: center; border-top: 1px solid rgba(255,255,255,0.1);">
                        <p style="color: #555; font-size: 11px; margin: 0;">© 2026 MovieWind. Todos los derechos reservados.</p>
                    </div>
                </div>
            `
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
