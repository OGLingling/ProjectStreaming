import express from 'express';
const router = express.Router();
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

// Ruta para ver todos los usuarios en el Admin Panel
router.get('/users', async (req, res) => {
    const users = await prisma.user.findMany();
    res.json(users);
});

export default router;
