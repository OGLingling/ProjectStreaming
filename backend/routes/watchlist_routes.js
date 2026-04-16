import express from 'express';
import { getWatchlist, toggleWatchlist } from '../controllers/watchlist_controller.js';

const router = express.Router();

router.get('/', getWatchlist);
router.post('/toggle', toggleWatchlist);

export default router;