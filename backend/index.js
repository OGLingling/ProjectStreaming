const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');
const nodemailer = require('nodemailer');

const app = express();
const prisma = new PrismaClient();

app.use(cors({
    origin: 'https://moviewind.netlify.app',
}));
app.use(express.json());

// --- CONFIGURACIÓN DE NODEMAILER ---
// Importante: Genera una "Contraseña de aplicación" en tu cuenta de Google
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
        // Buscamos si el usuario existe, si no, lo creamos (Upsert)
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
            from: '"MovieWind" <tu-correo@gmail.com>',
            to: email,
            subject: "Tu código de acceso - MovieWind",
            html: `
                <div style="font-family: Arial, sans-serif; line-height: 1.6;">
                    <h2>Bienvenido de vuelta a MovieWind</h2>
                    <p>Tu código de acceso a MovieWind es: <strong style="font-size: 24px; color: #E50914;">${otp}</strong></p>
                    <p>Tu código expirará en 15 min.</p>
                </div>
            `,
            text: `Bienvenido de vuelta a MovieWind, Tu código de acceso a MovieWind es ${otp}, tu código expirará en 15 min.`
        });

        console.log(`✅ OTP enviado a ${email}`);
        res.json({ success: true });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: "Error al enviar el código" });
    }
});

// 2. Verificar código
app.post('/api/auth/verify-otp', async (req, res) => {
    const { email, code } = req.body;

    try {
        const user = await prisma.user.findUnique({ where: { email } });

        if (user && user.pin === code && new Date() < user.pinExpiresAt) {
            // Limpiamos el PIN después de usarlo
            await prisma.user.update({
                where: { email },
                data: { pin: null, pinExpiresAt: null, isVerified: true }
            });
            res.json(user); // Enviamos los datos del usuario a Flutter
        } else {
            res.status(401).json({ error: "Código incorrecto o expirado" });
        }
    } catch (error) {
        res.status(500).json({ error: "Error al verificar" });
    }
});

// --- RUTAS DE PELÍCULAS ---

app.get('/api/movies', async (req, res) => {
  const { type } = req.query; 

  try {
    const content = await prisma.movie.findMany({
      where: type ? { type: String(type) } : {},
      orderBy: { releaseDate: 'desc' } // Las más nuevas primero
    });

    console.log(`📡 Enviando ${content.length} resultados de tipo: ${type || 'todos'}`);
    res.json(content);
  } catch (error) {
    console.error("❌ Error en la base de datos:", error);
    res.status(500).json({ error: "No se pudo conectar con la base de datos" });
  }
});

app.post("/api/movies", async (req, res) => {
    try {
        const { title, description, releaseDate, rating, imageUrl, category } = req.body;
        const nuevaPelicula = await prisma.movie.create({
            data: {
                title,
                description,
                releaseDate: new Date(releaseDate),
                rating: parseFloat(rating),
                imageUrl,
                category
            }
        });
        res.status(201).json(nuevaPelicula);
    } catch (error) {
        res.status(500).json({ error: "Error al guardar película" });
    }
});

// --- RUTAS DE USUARIO ---

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
    // Ahora recibimos también 'plan' y 'password' desde el body
    const { email, name, password, plan } = req.body; 

    // Normalizar el plan para que coincida con el Enum de Prisma (sin acentos)
    let planNormalizado = "basico";
    if (plan) {
        planNormalizado = plan.toLowerCase()
            .replace('á', 'a')
            .replace('é', 'e')
            .replace('í', 'i')
            .replace('ó', 'o')
            .replace('ú', 'u');
    }

    try {
        const user = await prisma.user.upsert({
            where: { email },
            update: { 
                name,
                plan: planNormalizado, // Actualiza el plan si el usuario ya existe
            }, 
            create: {
                email,
                name,
                password: password || "123456", // Usar default si viene vacío
                plan: planNormalizado,
                isVerified: true, 
            }
        });

        // Configuración del correo de bienvenida con datos dinámicos
        const mailOptions = {
            from: '"MovieWind" <tu-correo@gmail.com>', // Usa tu variable de entorno aquí
            to: email,
            subject: "¡Bienvenido a MovieWind!",
            html: `
                <div style="font-family: sans-serif; border: 1px solid #e50914; padding: 20px;">
                    <h1 style="color: #e50914;">¡Hola, ${name}!</h1>
                    <p>Tu cuenta en <b>MovieWind</b> ha sido creada con éxito.</p>
                    <p>Detalles de tu suscripción:</p>
                    <ul>
                        <li><b>Plan seleccionado:</b> ${plan.toUpperCase()}</li>
                        <li><b>Email:</b> ${email}</li>
                    </ul>
                    <p>¡Disfruta de las mejores películas y series!</p>
                </div>
            `
        };

        await transporter.sendMail(mailOptions);

        res.status(201).json(user); 
    } catch (error) {
        console.error("Error en registro:", error);
        res.status(500).json({ error: "No se pudo completar el registro" });
    }
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Servidor corriendo en el puerto ${PORT}`);
});