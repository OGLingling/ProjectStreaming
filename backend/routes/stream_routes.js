// routes/stream_routes.js
const express = require('express');
const router = express.Router();
const {
    getStreamLink,
    registerStream,
    getMasterPlaylist,
    getSource,
    getResource,
    getStatus,
    getHealth  // ← NUEVO
} = require('../controllers/stream_controller');

// Tus rutas existentes
router.get('/stream/link', getStreamLink);
router.post('/stream/register', registerStream);
router.get('/stream/status', getStatus);

// NUEVO: Health check integrado en stream_routes
router.get('/stream/health', getHealth);

// Rutas de proxy HLS
router.get('/stream/:streamId/master.m3u8', getMasterPlaylist);
router.get('/stream/:streamId/source', getSource);
router.get('/stream/:streamId/resource', getResource);

module.exports = router;