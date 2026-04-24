const express = require('express');
const router = express.Router();
const scraperController = require('../controllers/scraper_controller');

router.get('/extract', scraperController.extractLink);

module.exports = router;
