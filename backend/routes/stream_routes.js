const express = require('express');
const router = express.Router();
const streamController = require('../controllers/stream_controller');

router.post('/stream/register', streamController.registerStream);
router.get('/stream/register', streamController.registerStream);
router.get('/stream/:streamId/master.m3u8', streamController.getMasterPlaylist);
router.get('/stream/:streamId/source', streamController.getSource);
router.get('/stream/:streamId/resource', streamController.getResource);

module.exports = router;
