const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const createHelpTicket = async (req, res) => {
  const { category, message } = req.body;
  
  // Asume que el middleware de autenticación inyecta req.user.id
  // También permitimos fallback al body en caso de pruebas
  const userId = req.user?.id || req.body.userId;

  if (!userId) {
    return res.status(401).json({ error: 'Usuario no autenticado o userId no proporcionado' });
  }

  if (!category || !message) {
    return res.status(400).json({ error: 'La categoría y el mensaje son requeridos' });
  }

  try {
    const ticket = await prisma.helpTicket.create({
      data: {
        userId,
        category,
        message,
      },
    });

    res.status(201).json({
      success: true,
      message: 'Reporte de soporte creado exitosamente',
      ticket,
    });
  } catch (error) {
    console.error('Error al crear ticket de soporte:', error);
    res.status(500).json({ error: 'Error interno del servidor al crear el ticket', details: error.message });
  }
};

module.exports = {
  createHelpTicket,
};
