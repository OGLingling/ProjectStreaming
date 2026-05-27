const express = require('express');
const router = express.Router();
const { PrismaClient } = require('@prisma/client');
const { triggerManualCycle, getWorkerStatus } = require('../services/stream_worker');
const { enqueue, getQueueStats } = require('../services/scrape_queue');
const ContentService = require('../services/content_service');
const prisma = new PrismaClient();


// Middleware de autenticación básica para admin
const adminAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Basic ')) {
    return res.status(401).json({ error: 'Autenticación requerida' });
  }
  
  const credentials = Buffer.from(authHeader.slice(6), 'base64').toString('utf-8');
  const [username, password] = credentials.split(':');
  
  // Verificación de variables de entorno
  if (!process.env.ADMIN_USERNAME || !process.env.ADMIN_PASSWORD) {
    console.error('[admin] ❌ ADMIN_USERNAME o ADMIN_PASSWORD no configurados en .env / Render');
    return res.status(503).json({ error: 'Servicio administrativo no configurado' });
  }
  
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
      orderBy: { createdAt: 'desc' }
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
router.put('/users/:id/admin', async (req, res) => {
  try {
    const { id } = req.params;
    const { isAdmin } = req.body;

    if (!id || id === 'null' || id === 'undefined') {
      return res.status(400).json({ error: 'ID de usuario invalido' });
    }

    const user = await prisma.user.update({
      where: { id },
      data: { isAdmin: Boolean(isAdmin) },
      select: {
        id: true,
        email: true,
        name: true,
        plan: true,
        isAdmin: true,
        createdAt: true
      }
    });

    res.json(user);
  } catch (error) {
    console.error('Error actualizando rol admin:', error);
    if (error.code === 'P2025') {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.status(500).json({ error: 'Error al actualizar rol admin' });
  }
});

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
    const { tmdbId, title, description, type, imageUrl, backdropUrl } = req.body;

    if (!tmdbId) return res.status(400).json({ error: 'tmdbId requerido' });

    const imported = await ContentService.importFromTMDB(tmdbId, type || 'movie');
    if (!imported.success) {
      return res.status(502).json({ error: imported.error || 'No se pudo consultar TMDB' });
    }

    const overrides = {};
    if (title !== undefined) overrides.title = title;
    if (description !== undefined) overrides.description = description;
    if (imageUrl !== undefined) overrides.imageUrl = imageUrl;
    if (backdropUrl !== undefined) overrides.backdropUrl = backdropUrl;

    if (Object.keys(overrides).length > 0) {
      const content = await prisma.content.update({
        where: { tmdbId: String(tmdbId) },
        data: overrides
      });
      return res.json(content);
    }

    return res.json(imported.data);

    const content = await prisma.content.upsert({
      where: { tmdbId },
      update: { title, description, imageUrl, backdropUrl },
      create: {
        tmdbId,
        title: title || 'Sin título',
        description,
        type: type || 'movie',
        imageUrl,
        backdropUrl
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
    // Permite actualizar solo los campos de stream y metadatos básicos
    const { title, description, imageUrl, backdropUrl, videoUrl, streamSource, streamExpiresAt } = req.body;

    const data = {};
    if (title        !== undefined) data.title        = title;
    if (description  !== undefined) data.description  = description;
    if (imageUrl     !== undefined) data.imageUrl     = imageUrl;
    if (backdropUrl  !== undefined) data.backdropUrl  = backdropUrl;
    if (videoUrl     !== undefined) data.videoUrl     = videoUrl;
    if (streamSource !== undefined) data.streamSource = streamSource;
    if (streamExpiresAt !== undefined) data.streamExpiresAt = new Date(streamExpiresAt);

    const content = await prisma.content.update({
      where: { id: parseInt(id) },
      data
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

// --- ESTADO DEL WORKER DE SCRAPING ---
router.get('/scrape-status', async (req, res) => {
  try {
    const worker = getWorkerStatus();
    const queue  = getQueueStats();
    const now    = new Date();

    const [moviesTotal, moviesOk, moviesExpired, moviesNone,
           epsTotal,    epsOk,    epsExpired,    epsNone,
           jobsPending, jobsFailed] = await Promise.all([
      prisma.content.count({ where: { type: 'movie' } }),
      prisma.content.count({ where: { type: 'movie', videoUrl: { not: null }, streamExpiresAt: { gt: now } } }),
      prisma.content.count({ where: { type: 'movie', videoUrl: { not: null }, streamExpiresAt: { lt: now } } }),
      prisma.content.count({ where: { type: 'movie', videoUrl: null } }),
      prisma.episode.count(),
      prisma.episode.count({ where: { videoUrl: { not: null }, streamExpiresAt: { gt: now } } }),
      prisma.episode.count({ where: { videoUrl: { not: null }, streamExpiresAt: { lt: now } } }),
      prisma.episode.count({ where: { videoUrl: null } }),
      prisma.scrapeJob.count({ where: { status: 'pending' } }),
      prisma.scrapeJob.count({ where: { status: 'failed' } })
    ]);

    res.json({
      worker,
      queue,
      movies:   { total: moviesTotal, withStream: moviesOk, expired: moviesExpired, noStream: moviesNone },
      episodes: { total: epsTotal,    withStream: epsOk,    expired: epsExpired,    noStream: epsNone },
      jobs:     { pending: jobsPending, failed: jobsFailed }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// --- DISPARA CICLO DEL WORKER MANUALMENTE ---
router.post('/scrape-run', async (req, res) => {
  try {
    const result = await triggerManualCycle();
    res.json({ success: true, ...result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Alias para el panel
router.post('/trigger-worker', async (req, res) => {
  try {
    const result = await triggerManualCycle();
    res.json({ success: true, message: 'Ciclo de scraping iniciado manualmente', ...result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Endpoint simplificado para la terminal del admin panel
router.get('/logs/scraping', async (req, res) => {
  try {
    const logs = await prisma.scrapeLog.findMany({
      take: 50,
      orderBy: { createdAt: 'desc' }
    });
    // Mapear para compatibilidad con el frontend
    res.json(logs.map(l => ({
      timestamp: l.createdAt,
      message: `${l.success ? '✅' : '❌'} [${l.provider || 'System'}] ${l.targetUrl.split('/').pop()} - ${l.success ? 'OK' : 'Error'}`
    })));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// --- FORCE REFRESH DE UN CONTENIDO ESPECÍFICO ---
router.post('/scrape-force', async (req, res) => {
  try {
    const { tmdbId, type = 'movie', season = 1, episode = 1 } = req.body;
    if (!tmdbId) return res.status(400).json({ error: 'tmdbId requerido' });
    const result = await enqueue(tmdbId, type, Number(season), Number(episode), true);
    res.json({ success: true, ...result });
  } catch (error) {
    res.status(503).json({ success: false, error: error.message });
  }
});

// --- IMPORTACIÓN AUTOMÁTICA DESDE PANEL ---
// --- CONFIGURACIÓN DINÁMICA ---
router.get('/settings', (req, res) => {
  res.json({
    scraperMode: process.env.SCRAPER_MODE || 'auto',
    concurrent: Number(process.env.SCRAPER_CONCURRENT) || 1
  });
});

router.post('/settings', (req, res) => {
  const { scraperMode } = req.body;
  if (scraperMode) {
    process.env.SCRAPER_MODE = scraperMode;
    console.log(`[admin] ⚙️ Scraper Mode actualizado a: ${scraperMode}`);
  }
  res.json({ success: true, scraperMode: process.env.SCRAPER_MODE });
});

router.post('/import-content', async (req, res) => {
  try {
    const { title, type } = req.body;
    if (!title) return res.status(400).json({ error: 'El título es requerido' });

    console.log(`[admin] 🚀 Iniciando importación remota: "${title}" (${type})`);
    const result = await ContentService.autoImportByTitle(title, type || 'movie');

    if (result.success) {
      res.json({ 
        success: true, 
        message: `¡${result.data.title} importado correctamente!`,
        content: result.data 
      });
    } else {
      res.status(404).json({ success: false, error: result.error });
    }
  } catch (error) {
    console.error('[admin] Error en import-content:', error);
    res.status(500).json({ error: 'Error interno al procesar la importación' });
  }
});

module.exports = router;
