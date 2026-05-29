const express = require('express');
const { createHelpTicket } = require('../controllers/help_controller');

const router = express.Router();

router.post('/tickets', createHelpTicket);

module.exports = router;
