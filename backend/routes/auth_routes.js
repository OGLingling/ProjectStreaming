// routes/auth.routes.js
import express from 'express';
const router = express.Router();
import authController from '../controllers/auth_controller.js';

// Mapeo de rutas
router.post('/send-otp', authController.sendOtp);
router.post('/verify-otp', authController.verifyOtp);
router.post('/register', authController.register);
router.get('/users', authController.getUserByEmail); // Cambié la ruta a /user para ser más descriptivo
router.put('/users/:id', authController.updateUser);

export default router;
