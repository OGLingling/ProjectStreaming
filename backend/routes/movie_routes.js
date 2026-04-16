const express = require('express');
const router = express.Router();
const movieController = require('../controllers/movie_controller');

router.get('/', movieController.getMovies);
router.get('/proxy-stream', movieController.proxyStream);

module.exports = router;