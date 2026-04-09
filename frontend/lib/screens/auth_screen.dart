import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'plan_selection_screen.dart';

enum AuthStep { loginEmail, loginCode, registerLanding, registerPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _codeFocusNodes = List.generate(4, (_) => FocusNode());

  AuthStep _currentStep = AuthStep.registerLanding;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final String _bgPosters =
      "https://wallpapers.com/images/hd/netflix-background-gs7hjuwvv2g0e9fj.jpg";

  // ─── LÓGICA DE NAVEGACIÓN Y AUTENTICACIÓN ──────────────────────────────────

  Future<void> _handleAction() async {
    if (_isLoading) return;

    final email = _emailController.text.trim().toLowerCase();

    if ((_currentStep == AuthStep.registerLanding ||
            _currentStep == AuthStep.loginEmail) &&
        (!email.contains('@') || !email.contains('.'))) {
      _showErrorSnackBar("Ingresa un email válido");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_currentStep == AuthStep.registerLanding ||
          _currentStep == AuthStep.loginEmail) {
        // 1. Buscamos al usuario
        final userData = await ApiService.getUserDataByEmail(email);

        if (userData != null && userData.isNotEmpty) {
          // ✅ EXISTE: Solicitar OTP y cambiar a pantalla de código
          await _solicitarOTP();
        } else {
          // ❌ NO EXISTE: Ir a registro
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          setState(() {
            _currentStep = AuthStep.registerPassword;
          });
        }
      } else if (_currentStep == AuthStep.registerPassword) {
        _procederAlRegistro(email);
      } else if (_currentStep == AuthStep.loginCode) {
        await _verificarOTPyEntrar();
      }
    } catch (e) {
      debugPrint("Error en Auth: $e");
      _showErrorSnackBar("Error de conexión con el servidor");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _procederAlRegistro(String email) {
    final nombre = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (nombre.isEmpty) {
      _showErrorSnackBar("Por favor ingresa tu nombre");
      return;
    }
    if (password.length < 6) {
      _showErrorSnackBar("La contraseña debe tener al menos 6 caracteres");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanSelectionScreen(
          userEmail: email,
          userName: nombre,
          password: password,
        ),
      ),
    );
  }

  // ─── LÓGICA DE OTP (LOGIN) ─────────────────────────────────────────────────

  Future<void> _solicitarOTP() async {
    final email = _emailController.text.trim().toLowerCase();

    // Trigger para que el backend genere el PIN y envíe el correo
    final success = await ApiService.sendOTP(email);

    if (!mounted) return;

    if (success) {
      setState(() {
        _currentStep = AuthStep.loginCode; // Cambia la UI a los 4 cuadros
      });
      _showSuccessSnackBar("Código enviado a $email");
    } else {
      _showErrorSnackBar("No se pudo enviar el código. Reintenta.");
    }
  }

  Future<void> _verificarOTPyEntrar() async {
    final String code = _codeControllers.map((e) => e.text).join();

    if (code.length < 4) {
      _showErrorSnackBar("Ingresa el código completo");
      return;
    }

    try {
      final userData = await ApiService.verifyOTP(
        _emailController.text.trim().toLowerCase(),
        code,
      );

      if (!mounted) return;

      if (userData != null) {
        await _guardarSesionYNavegar(userData);
      } else {
        _showErrorSnackBar("Código incorrecto o expirado");
      }
    } catch (e) {
      _showErrorSnackBar("Error al verificar el código");
    }
  }

  Future<void> _guardarSesionYNavegar(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userData['id'].toString());
    await prefs.setString(
      'user_email',
      userData['email'] ?? _emailController.text.trim(),
    );
    await prefs.setBool('is_logged_in', true);

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/profiles',
      (route) => false,
      arguments: userData,
    );
  }

  // ─── UI BUILDING ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isDarkBg = _currentStep != AuthStep.registerPassword;

    return Scaffold(
      backgroundColor: isDarkBg ? Colors.black : Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          if (isDarkBg) _buildModernBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDarkBg),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 20,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: _buildStepContent(isDarkBg),
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

  Widget _buildModernBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          _bgPosters,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(color: Colors.black),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.9),
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.95),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    final bool isAtLogin =
        _currentStep == AuthStep.loginEmail ||
        _currentStep == AuthStep.loginCode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "MOVIEWIND",
            style: GoogleFonts.montserrat(
              color: const Color(0xFFE50914),
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: -0.8,
            ),
          ),
          if (_currentStep == AuthStep.registerLanding || isAtLogin)
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: isAtLogin
                    ? Colors.transparent
                    : const Color(0xFFE50914),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: () {
                setState(() {
                  _currentStep = isAtLogin
                      ? AuthStep.registerLanding
                      : AuthStep.loginEmail;
                });
              },
              child: Text(
                isAtLogin ? "Regístrate" : "Iniciar sesión",
                style: GoogleFonts.geologica(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case AuthStep.registerLanding:
        return _buildRegisterLanding();
      case AuthStep.loginEmail:
        return _buildLoginEmail();
      case AuthStep.registerPassword:
        return _buildRegisterPassword();
      case AuthStep.loginCode:
        return _buildLoginCode();
    }
  }

  Widget _buildRegisterLanding() {
    return Column(
      children: [
        Text(
          "Películas y series ilimitadas y mucho más",
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "A partir de S/ 24.90. Cancela cuando quieras.",
          style: GoogleFonts.geologica(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 25),
        _buildNetflixTextField(_emailController, "Email"),
        const SizedBox(height: 15),
        _buildNetflixButton("Comenzar >", _handleAction),
      ],
    );
  }

  Widget _buildLoginEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Inicia sesión",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),
        _buildNetflixTextField(_emailController, "Email"),
        const SizedBox(height: 20),
        _buildNetflixButton("Continuar", _handleAction),
      ],
    );
  }

  Widget _buildRegisterPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "PASO 1 DE 3",
          style: GoogleFonts.geologica(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Crea una contraseña para comenzar tu membresía",
          style: GoogleFonts.montserrat(
            color: Colors.black,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 25),
        _buildNetflixTextField(
          _nameController,
          "Nombre completo",
          isDark: false,
        ),
        const SizedBox(height: 15),
        _buildNetflixTextField(
          _passwordController,
          "Contraseña",
          isDark: false,
          isPassword: true,
        ),
        const SizedBox(height: 30),
        _buildNetflixButton("SIGUIENTE", _handleAction),
      ],
    );
  }

  Widget _buildLoginCode() {
    return Column(
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          color: Colors.white,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          "Verifica tu código",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Enviamos un código de 4 dígitos a\n${_emailController.text.trim()}",
          textAlign: TextAlign.center,
          style: GoogleFonts.geologica(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) => _buildCodeBox(i)),
        ),
        const SizedBox(height: 30),
        _buildNetflixButton("Entrar", _handleAction),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : _solicitarOTP,
          child: const Text(
            "¿No recibiste el código? Reenviar",
            style: TextStyle(
              color: Colors.white60,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // ─── COMPONENTES REUTILIZABLES ─────────────────────────────────────────────

  Widget _buildNetflixTextField(
    TextEditingController controller,
    String hint, {
    bool isDark = true,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        filled: true,
        fillColor: isDark
            ? Colors.grey[900]!.withOpacity(0.8)
            : Colors.grey[100],
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  Widget _buildNetflixButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE50914),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    return Container(
      width: 60,
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white10,
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _codeFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 24),
        maxLength: 1,
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 3) {
            _codeFocusNodes[index + 1].requestFocus();
          }
          if (v.isEmpty && index > 0) _codeFocusNodes[index - 1].requestFocus();
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final n in _codeFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }
}
