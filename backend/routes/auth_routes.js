// routes/auth.routes.js
const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');

// Mapeo de rutas
router.post('/send-otp', authController.sendOtp);
router.post('/verify-otp', authController.verifyOtp);
router.post('/register', authController.register);
router.get('/user', authController.getUserByEmail); // Cambié la ruta a /user para ser más descriptivo
router.put('/user/:id', authController.updateUser);

module.exports = router;