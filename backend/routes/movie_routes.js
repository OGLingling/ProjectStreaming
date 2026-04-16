import express from 'express';
const router = express.Router();
import movieController from '../controllers/movie_controller.js';

router.get('/', movieController.getMovies);
router.get('/proxy-stream', movieController.proxyStream);

export default router;
