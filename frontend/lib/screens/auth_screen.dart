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

  // --- LOGIN MANUAL ---
  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar("Por favor, ingresa correo y contraseña");
      return;
    }
    setState(() => _isLoading = true);

    try {
      final firebase_auth.UserCredential userCredential = await firebase_auth
          .FirebaseAuth
          .instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;

      if (user != null) {
        await user.reload(); // Actualiza el estado de verificación
        final updatedUser = firebase_auth.FirebaseAuth.instance.currentUser;

        if (updatedUser != null && !updatedUser.emailVerified) {
          _showErrorSnackBar("Por favor, verifica tu correo electrónico.");
          await firebase_auth.FirebaseAuth.instance.signOut();
          return;
        }

        // Sincronizamos con Neon usando el método que corregimos en ApiService
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

        print("Login y sincronización exitosos");
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      _showErrorSnackBar("Correo o contraseña incorrectos.");
    } catch (e) {
      _showErrorSnackBar("Error de Conexión o Sincronización");
      print("Error detalle: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REGISTRO ---
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
      final firebase_auth.UserCredential userCredential = await firebase_auth
          .FirebaseAuth
          .instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // Enviar correo de verificación
        await firebaseUser.sendEmailVerification();

        // Sincronizar inicialmente con Neon (isVerified será false al principio)
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text(
                "Registro exitoso, por favor verifica tu correo en Gmail.",
              ),
            ),
          );
          setState(() => _isLogin = true);
        }
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      _showErrorSnackBar(e.message ?? "Error en Firebase");
    } catch (e) {
      _showErrorSnackBar("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "MOVIEWIND",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 38.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 40),
                if (!_isLogin) ...[
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Nombre"),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Email"),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Contraseña"),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_isLogin ? _login : _register),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
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
                          _isLogin ? "Iniciar Sesión" : "Registrarse",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "O",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin
                        ? "¿Nuevo en Moviewind? Suscríbete ahora."
                        : "¿Ya tienes cuenta? Inicia sesión.",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF333333),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4.0),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
