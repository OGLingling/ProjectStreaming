const express = require('express');
const { transferProfile } = require('../controllers/profile_controller');

const router = express.Router();

router.post('/transfer', transferProfile);

module.exports = router;
