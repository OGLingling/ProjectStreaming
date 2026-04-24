const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Middleware de autenticación básica para admin
const adminAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Basic ')) {
    return res.status(401).json({ error: 'Autenticación requerida' });
  }
  
  const credentials = Buffer.from(authHeader.slice(6), 'base64').toString('utf-8');
  const [username, password] = credentials.split(':');
  
  // Credenciales hardcodeadas (puedes cambiarlas por variables de entorno)
  if (username !== process.env.ADMIN_USERNAME || password !== process.env.ADMIN_PASSWORD) {
    return res.status(401).json({ error: 'Credenciales inválidas' });
  }
  
  next();
};

// Aplicar autenticación a todas las rutas admin
router.use(adminAuth);

// --- ESTADÍSTICAS Y ANALYTICS ---
router.get('/stats', async (req, res) => {
  try {
    console.log('Petición recibida en Admin Stats');
    const [
      totalUsers,
      totalContents,
      scrapingRequests,
      failedScrapes
    ] = await Promise.all([
      prisma.user.count(),
      prisma.content.count(),
      prisma.scrapeLog.count(),
      prisma.scrapeLog.count({ where: { success: false } })
    ]);
    
    res.json({
      totalUsers,
      totalContents,
      scrapingRequests,
      failedScrapes,
      successRate: scrapingRequests > 0 
        ? ((scrapingRequests - failedScrapes) / scrapingRequests * 100).toFixed(2)
        : 0
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// --- ACTIVIDAD RECIENTE PARA DASHBOARD ---
router.get('/recent-activity', async (req, res) => {
  try {
    console.log('Petición recibida en Admin Recent Activity');
    
    // Obtener logs recientes (últimas 10 actividades)
    const recentLogs = await prisma.scrapeLog.findMany({
      take: 10,
      orderBy: { createdAt: 'desc' },
      include: {
        content: {
          select: { title: true }
        }
      }
    });
    
    res.json(recentLogs);
  } catch (error) {
    console.error('Error en recent-activity:', error.message);
    res.status(500).json({ error: 'Error al obtener actividad reciente' });
  }
});

// --- GESTIÓN DE USUARIOS ---
router.get('/users', async (req, res) => {
  try {
    console.log('🔍 Intentando conectar a la base de datos para obtener usuarios...');
    const users = await prisma.user.findMany({
      include: {
        _count: {
          select: { myList: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });
    console.log(`✅ Obtenidos ${users.length} usuarios correctamente`);
    res.json(users);
  } catch (error) {
    console.error('❌ Error crítico en /api/admin/users:', error);
    console.error('🔧 Detalles del error Prisma:', {
      code: error.code,
      meta: error.meta,
      message: error.message,
      stack: error.stack
    });
    
    // Diagnóstico específico de errores de conexión
    if (error.code === 'P1001') {
      console.error('🚨 Error de conexión a la base de datos - Verificar URL de conexión');
    } else if (error.code === 'P1017') {
      console.error('🚨 La base de datos ha cerrado la conexión');
    } else if (error.code === 'P2024') {
      console.error('🚨 Timeout en la conexión a la base de datos');
    }
    
    res.status(500).json({ 
      error: 'Error interno del servidor',
      details: process.env.NODE_ENV === 'development' ? error.message : 'Contacte al administrador'
    });
  }
});

// --- GESTIÓN DE CONTENIDOS (CRUD) ---
router.get('/contents', async (req, res) => {
  try {
    const { page = 1, limit = 20, search = '', type } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const where = {
      OR: [
        { title: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } }
      ]
    };
    
    if (type) {
      where.type = type;
    }
    
    const contents = await prisma.content.findMany({
      where,
      skip,
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' },
      include: {
        seasons: {
          include: {
            episodes: true
          }
        }
      }
    });
    
    const total = await prisma.content.count({ where });
    
    res.json({ contents, total, page: parseInt(page), totalPages: Math.ceil(total / parseInt(limit)) });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/contents', async (req, res) => {
  try {
    const { tmdbId, title, description, type, imageUrl, backdropUrl, vsembedUrl, vidsrcUrl } = req.body;
    
    const content = await prisma.content.upsert({
      where: { tmdbId },
      update: { vsembedUrl, vidsrcUrl },
      create: {
        tmdbId,
        title,
        description,
        type: type || 'movie',
        imageUrl,
        backdropUrl,
        vsembedUrl,
        vidsrcUrl
      }
    });
    
    res.json(content);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.put('/contents/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { vsembedUrl, vidsrcUrl } = req.body;
    
    const content = await prisma.content.update({
      where: { id: parseInt(id) },
      data: { vsembedUrl, vidsrcUrl }
    });
    
    res.json(content);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.delete('/contents/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    await prisma.content.delete({
      where: { id: parseInt(id) }
    });
    
    res.json({ message: 'Contenido eliminado correctamente' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// --- LOGS DE SCRAPING Y ERRORES ---
router.get('/scraping-logs', async (req, res) => {
  try {
    const { page = 1, limit = 50, success } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const where = {};
    if (success !== undefined) {
      where.success = success === 'true';
    }
    
    const logs = await prisma.scrapeLog.findMany({
      where,
      skip,
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' }
    });
    
    const total = await prisma.scrapeLog.count({ where });
    
    res.json({ logs, total, page: parseInt(page), totalPages: Math.ceil(total / parseInt(limit)) });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// --- REPORTES DE ENLACES CAÍDOS ---
router.get('/broken-links', async (req, res) => {
  try {
    const brokenLinks = await prisma.scrapeLog.findMany({
      where: { 
        success: false,
        createdAt: { 
          gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) // Últimos 7 días
        }
      },
      distinct: ['targetUrl'],
      orderBy: { createdAt: 'desc' },
      take: 100
    });
    
    res.json(brokenLinks);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;