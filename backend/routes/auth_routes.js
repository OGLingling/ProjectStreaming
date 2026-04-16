// routes/auth.routes.js
const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth_controller');

// Mapeo de rutas
router.post('/send-otp', authController.sendOtp);
router.post('/verify-otp', authController.verifyOtp);
router.post('/register', authController.register);
router.get('/users', authController.getUserByEmail); // Cambié la ruta a /user para ser más descriptivo
router.put('/users/:id', authController.updateUser);

module.exports = router;