const express = require('express');
const { getWatchlist, toggleWatchlist } = require('../controllers/watchlist_controller');

const router = express.Router();

router.get('/', getWatchlist);
router.post('/toggle', toggleWatchlist);

module.exports = router;
