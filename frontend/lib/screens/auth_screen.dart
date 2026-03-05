import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

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

  // URL de fondo para el registro (Estilo posters)
  final String _bgRegister =
      "https://assets.nflxext.com/ffe/siteui/vlv3/f841d4c7-10e1-40af-bcae-07a3f8dc141a/f6bc1730-68f9-4316-b1e8-7133036e4f32/US-en-20220502-popsignuptwoweeks-perspective_alpha_website_medium.jpg";

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
      final user = userCredential.user;
      if (user != null) {
        await user.reload();
        final updatedUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (updatedUser != null && !updatedUser.emailVerified) {
          _showErrorSnackBar("Verifica tu correo electrónico.");
          await firebase_auth.FirebaseAuth.instance.signOut();
          return;
        }
        await _apiService.registerUser(
          User(
            id: updatedUser!.uid,
            email: updatedUser.email!,
            password: password,
            name: _nameController.text.isEmpty
                ? "Usuario de MovieWind"
                : _nameController.text,
            isVerified: updatedUser.emailVerified,
          ),
          updatedUser.emailVerified,
        );
      }
    } catch (e) {
      _showErrorSnackBar("Error de acceso. Revisa tus datos.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      _showErrorSnackBar("Todos los campos son obligatorios");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userCredential = await firebase_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await firebaseUser.sendEmailVerification();
        await _apiService.registerUser(
          User(
            id: firebaseUser.uid,
            email: email,
            password: password,
            name: name,
            isVerified: false,
          ),
          false,
        );
        if (mounted) {
          _showSuccessSnackBar("¡Registro exitoso! Verifica tu Gmail.");
          setState(() => _isLogin = true);
        }
      }
    } catch (e) {
      _showErrorSnackBar("Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // FONDO DINÁMICO
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _isLogin
                ? Container(
                    key: const ValueKey(1),
                    color: Colors.black,
                  ) // Login: Fondo Negro
                : Container(
                    // Registro: Fondo Posters (Imagen 2)
                    key: const ValueKey(2),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(_bgRegister),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.7),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                  ),
          ),
          // CONTENIDO
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "MOVIEWIND",
                      textAlign: _isLogin ? TextAlign.left : TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE50914),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      _isLogin
                          ? "Ingresa tu info para iniciar sesión"
                          : "Películas y series ilimitadas y mucho más",
                      textAlign: _isLogin ? TextAlign.left : TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _isLogin ? 28 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isLogin
                          ? "O bien, comienza con una cuenta nueva."
                          : "A partir de S/ 10.90. Cancela cuando quieras.",
                      textAlign: _isLogin ? TextAlign.left : TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (!_isLogin) ...[
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("Nombre completo"),
                      ),
                      const SizedBox(height: 15),
                    ],
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Email o número de celular"),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("Contraseña"),
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_isLogin ? _login : _register),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
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
                              _isLogin ? "Continuar" : "Comenzar >",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? "¿Nuevo en Moviewind? Suscríbete ahora."
                            : "¿Ya tienes cuenta? Inicia sesión.",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: const Color(0xFF161616),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white30),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
