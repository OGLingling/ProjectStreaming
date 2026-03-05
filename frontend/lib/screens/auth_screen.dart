import 'package:flutter/material.dart';
import 'dart:ui'; // Para el efecto blur
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'movies_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLogin = true;
  bool _isLoading = false;

  final String _bgRegister =
      "https://assets.nflxext.com/ffe/siteui/vlv3/f841d4c7-10e1-40af-bcae-07a3f8dc141a/f6bc1730-68f9-4316-b1e8-7133036e4f32/US-en-20220502-popsignuptwoweeks-perspective_alpha_website_medium.jpg";

  // Lógica de Login/Registro se mantiene igual (solo añadí navegación al éxito)
  void _handleAuth() async {
    if (_isLogin) {
      _login();
    } else {
      _register();
    }
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar("Ingresa tus credenciales");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userCredential = await firebase_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        if (!userCredential.user!.emailVerified) {
          _showErrorSnackBar("Verifica tu correo electrónico.");
          await firebase_auth.FirebaseAuth.instance.signOut();
          return;
        }
        // Navegar a Home
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MoviesScreen()),
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar("Error de acceso. Revisa tus datos.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _register() async {
    // Aquí podrías implementar la navegación a las pantallas blancas de pasos (Step 1, 2, 3)
    // Por ahora, mantenemos la lógica base en esta pantalla estilizada
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackBar("Ingresa un email para comenzar");
      return;
    }
    setState(
      () => _isLogin = false,
    ); // Simplemente mostramos el formulario completo

    // Si ya llenó todo, procedemos:
    if (_passwordController.text.isNotEmpty &&
        _nameController.text.isNotEmpty) {
      // Lógica de creación en Firebase...
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // --- FONDO CON EFECTO NETFLIX ---
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: _isLogin
                ? Container(key: const ValueKey(1), color: Colors.black)
                : Stack(
                    key: const ValueKey(2),
                    fit: StackFit.expand,
                    children: [
                      Image.network(_bgRegister, fit: BoxFit.cover),
                      ClipRect(
                        // Blur para que el texto resalte como en la imagen 176c09
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                          child: Container(
                            color: Colors.black.withOpacity(0.65),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // --- CONTENIDO ---
          SafeArea(
            child: Column(
              children: [
                // Header (Logo)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: _isLogin
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "MOVIEWIND",
                        style: TextStyle(
                          color: Color(0xFFE50914),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (!_isLogin)
                        TextButton(
                          onPressed: () => setState(() => _isLogin = true),
                          child: const Text(
                            "Iniciar sesión",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: _isLogin
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.center,
                          children: [
                            // Títulos dinámicos
                            Text(
                              _isLogin
                                  ? "Iniciar sesión"
                                  : "Películas y series ilimitadas y mucho más",
                              textAlign: _isLogin
                                  ? TextAlign.left
                                  : TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              _isLogin
                                  ? "Disfruta de MovieWind en todos tus dispositivos."
                                  : "A partir de S/ 10.90. Cancela cuando quieras.",
                              textAlign: _isLogin
                                  ? TextAlign.left
                                  : TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 35),

                            // --- FORMULARIO ---
                            if (!_isLogin) ...[
                              _buildTextField(
                                _nameController,
                                "Nombre completo",
                              ),
                              const SizedBox(height: 15),
                            ],
                            _buildTextField(
                              _emailController,
                              "Email o número de celular",
                            ),
                            const SizedBox(height: 15),
                            _buildTextField(
                              _passwordController,
                              "Contraseña",
                              isPassword: true,
                            ),

                            const SizedBox(height: 30),

                            // BOTÓN PRINCIPAL
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE50914),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _handleAuth,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isLogin
                                            ? "Iniciar sesión"
                                            : "Comenzar >",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Switch entre login y registro
                            Center(
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _isLogin = !_isLogin),
                                child: Text(
                                  _isLogin
                                      ? "¿Nuevo en MovieWind? Suscríbete ahora."
                                      : "¿Ya tienes cuenta? Inicia sesión.",
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: Colors.grey[900]!.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white60, width: 1),
        ),
      ),
    );
  }

  // SnackBar helpers... (mantener tus funciones _showErrorSnackBar y _showSuccessSnackBar)
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
