const express = require('express');
const router = express.Router();
const streamController = require('../controllers/stream_controller');

// ─── Proxy HLS / MP4 ────────────────────────────────────────────────────────
router.post('/stream/register', streamController.registerStream);
router.get('/stream/register', streamController.registerStream);
router.get('/stream/:streamId/master.m3u8', streamController.getMasterPlaylist);
router.get('/stream/:streamId/source', streamController.getSource);
router.get('/stream/:streamId/resource', streamController.getResource);

// ─── Re-scraping forzado (admin/debug) ──────────────────────────────────────
// POST /api/stream/force-refresh?tmdbId=XXX&type=movie
router.post('/stream/force-refresh', streamController.forceRefresh);
router.get('/stream/force-refresh', streamController.forceRefresh);

// ─── Dispara manualmente el ciclo del worker ─────────────────────────────────
// POST /api/stream/worker/run
router.post('/stream/worker/run', streamController.runWorkerCycle);

module.exports = router;
