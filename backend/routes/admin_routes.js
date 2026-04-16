const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Ruta para ver todos los usuarios en el Admin Panel
router.get('/users', async (req, res) => {
    const users = await prisma.user.findMany();
    res.json(users);
});

module.exports = router;