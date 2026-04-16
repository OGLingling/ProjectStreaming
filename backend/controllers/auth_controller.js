const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// --- FUNCIÓN PRIVADA: ENVÍO DE EMAIL VÍA BREVO ---
async function sendEmail(to, subject, htmlContent) {
    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: {
            'accept': 'application/json',
            'api-key': process.env.BREVO_API_KEY,
            'content-type': 'application/json'
        },
        body: JSON.stringify({
            sender: { name: 'MovieWind', email: 'moviewindsupport@gmail.com' },
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

// --- 1. ENVIAR OTP ---
exports.sendOtp = async (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: "Email requerido" });

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const normalizedEmail = email.toLowerCase().trim();

    try {
        await prisma.user.upsert({
            where: { email: normalizedEmail },
            update: { pin: otp, pinExpiresAt: new Date(Date.now() + 15 * 60000) },
            create: { email: normalizedEmail, pin: otp, pinExpiresAt: new Date(Date.now() + 15 * 60000), name: "Usuario Nuevo" }
        });

        await sendEmail(normalizedEmail, "Tu codigo de acceso - MovieWind", `
            <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 500px; margin: 0 auto; background: #1a1a2e; border-radius: 16px; overflow: hidden; padding: 20px;">
                <h1 style="color: #E50914; text-align: center;">MovieWind</h1>
                <h2 style="color: white; text-align: center;">Codigo: ${otp}</h2>
            </div>
        `);
        res.json({ success: true });
    } catch (error) {
        console.error("Error en sendOtp:", error);
        res.status(500).json({ error: "Error al enviar el correo" });
    }
};

// --- 2. VERIFICAR OTP ---
exports.verifyOtp = async (req, res) => {
    const { email, code } = req.body;
    if (!email || !code) return res.status(400).json({ error: "Email y código requeridos" });

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
        res.status(500).json({ error: "Error al verificar" });
    }
};

// --- 3. OBTENER USUARIO POR EMAIL ---
exports.getUserByEmail = async (req, res) => {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: "Email requerido" });

    try {
        const user = await prisma.user.findUnique({ 
            where: { email: String(email).toLowerCase().trim() } 
        });
        res.json(user || null);
    } catch (error) {
        res.status(500).json({ error: "Error al buscar usuario" });
    }
};

// --- 4. REGISTRO (UPSERT) ---
exports.register = async (req, res) => {
    const { email, name, password, plan } = req.body;
    if (!email) return res.status(400).json({ error: "Email requerido" });

    const normalizedEmail = email.toLowerCase().trim();
    let planNormalizado = plan ? plan.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "") : "basico";

    try {
        const user = await prisma.user.upsert({
            where: { email: normalizedEmail },
            update: { name, plan: planNormalizado },
            create: { email: normalizedEmail, name, password: password || "123456", plan: planNormalizado, isVerified: true }
        });

        await sendEmail(normalizedEmail, "Bienvenido a MovieWind!", `<h2>Bienvenido, ${name}!</h2>`);
        res.status(201).json(user);
    } catch (error) {
        res.status(500).json({ error: "Error en registro" });
    }
};

// --- 5. ACTUALIZAR PERFIL (PUT) ---
exports.updateUser = async (req, res) => {
    const { id } = req.params;
    const { name, profilePic, plan } = req.body;

    try {
        const userUpdated = await prisma.user.update({
            where: { id: id },
            data: { name, profilePic, plan },
        });
        res.json(userUpdated);
    } catch (error) {
        res.status(500).json({ error: "Error al actualizar" });
    }
};