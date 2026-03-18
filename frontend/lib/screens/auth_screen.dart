import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'plan_selection_screen.dart';

enum AuthStep { loginEmail, loginCode, registerLanding, registerPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  _AuthScreenState createState() => _AuthScreenState();
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

  final String _bgPosters =
      "https://wallpapers.com/images/hd/netflix-background-gs7hjuwvv2g0e9fj.jpg";

  // --- LÓGICA DE ACCIÓN PRINCIPAL (Sin Cambios) ---

  Future<void> _handleAction() async {
    if (_isLoading) return;

    if (_currentStep == AuthStep.registerLanding &&
        !_emailController.text.contains('@')) {
      _showErrorSnackBar("Ingresa un email válido");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_currentStep == AuthStep.registerLanding) {
        setState(() => _currentStep = AuthStep.registerPassword);
      } else if (_currentStep == AuthStep.registerPassword) {
        if (_passwordController.text.length >= 6 &&
            _nameController.text.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlanSelectionScreen(
                userEmail: _emailController.text,
                userName: _nameController.text,
                password: _passwordController.text,
              ),
            ),
          );
        } else {
          _showErrorSnackBar("Nombre y clave (min. 6 carac.) requeridos");
        }
      } else if (_currentStep == AuthStep.loginEmail) {
        await _solicitarOTP();
      } else if (_currentStep == AuthStep.loginCode) {
        await _verificarOTPyEntrar();
      }
    } catch (e) {
      _showErrorSnackBar("Error de conexión con el servidor");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LÓGICA DE LOGIN (Sin Cambios) ---

  Future<void> _solicitarOTP() async {
    final success = await ApiService.sendOTP(_emailController.text);
    if (success) {
      setState(() => _currentStep = AuthStep.loginCode);
      _showSuccessSnackBar("Código enviado a ${_emailController.text}");
    } else {
      _showErrorSnackBar("El correo no está registrado o hubo un error.");
    }
  }

  Future<void> _verificarOTPyEntrar() async {
    String code = _codeControllers.map((e) => e.text).join();

    if (code.length < 4) {
      _showErrorSnackBar("Por favor, ingresa el código de 4 dígitos");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = await ApiService.verifyOTP(_emailController.text, code);

      if (userData != null) {
        debugPrint("Login exitoso. Datos del usuario: $userData");
        await _guardarSesionYNavegar(userData);
      } else {
        _showErrorSnackBar("Código incorrecto o expirado");
      }
    } catch (e) {
      debugPrint("Error en verificación: $e");
      _showErrorSnackBar("Error de conexión al verificar el código");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarSesionYNavegar(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userData['id'].toString());
    await prefs.setString(
      'user_email',
      userData['email'] ?? _emailController.text,
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

  // --- UI COMPONENTS REDISEÑADOS VISUALMENTE ---

  @override
  Widget build(BuildContext context) {
    bool isDarkBg = _currentStep != AuthStep.registerPassword;

    return Scaffold(
      backgroundColor: isDarkBg ? Colors.black : Colors.white,
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
                      padding: const EdgeInsets.symmetric(horizontal: 25),
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
        // Gradiente profundo como en la foto
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.85),
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
    bool isAtLogin =
        _currentStep == AuthStep.loginEmail ||
        _currentStep == AuthStep.loginCode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LOGO ORIGINAL RESTAURADO AL 100%
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
                  _nameController.clear();
                  _passwordController.clear();
                });
              },
              child: Text(
                isAtLogin ? "Registrate" : "Iniciar sesión",
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
            fontSize: 38,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "A partir de S/ 28.90. Cancela cuando quieras.",
          style: GoogleFonts.geologica(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 25),
        Text(
          "¿Quieres ver MovieWind ya? Ingresa tu email para crear una cuenta o reiniciar tu membresía.",
          textAlign: TextAlign.center,
          style: GoogleFonts.geologica(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 20),
        _buildNetflixTextField(_emailController, "Email"),
        const SizedBox(height: 15),
        _buildNetflixButton("Comenzar >", () => _handleAction()),
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
        const SizedBox(height: 10),
        Text(
          "O bien, comienza con una cuenta nueva.",
          style: GoogleFonts.geologica(color: Colors.white70),
        ),
        const SizedBox(height: 30),
        _buildNetflixTextField(_emailController, "Email o número de celular"),
        const SizedBox(height: 20),
        _buildNetflixButton("Continuar", () => _handleAction()),
        const SizedBox(height: 15),
        Center(
          child: TextButton(
            onPressed: () {},
            child: Text(
              "Obtener ayuda ∨",
              style: GoogleFonts.geologica(color: Colors.white70),
            ),
          ),
        ),
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
        Text(
          "Crea una contraseña para comenzar tu membresía",
          style: GoogleFonts.montserrat(
            color: Colors.black,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 25),
        _buildNetflixTextField(_nameController, "Nombre", isDark: false),
        const SizedBox(height: 15),
        _buildNetflixTextField(
          _passwordController,
          "Contraseña",
          isDark: false,
          isPassword: true,
        ),
        const SizedBox(height: 30),
        _buildNetflixButton("SIGUIENTE", () => _handleAction()),
      ],
    );
  }

  Widget _buildLoginCode() {
    return Column(
      children: [
        Text(
          "Verifica tu código",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) => _buildCodeBox(i)),
        ),
        const SizedBox(height: 30),
        _buildNetflixButton("Entrar", () => _handleAction()),
      ],
    );
  }

  // --- ELEMENTOS DE DISEÑO ATÓMICOS CORREGIDOS ---

  Widget _buildNetflixTextField(
    TextEditingController controller,
    String hint, {
    bool isDark = true,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        filled: true,
        fillColor: isDark ? Colors.grey[900]!.withOpacity(0.85) : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isDark ? Colors.white : const Color(0xFFE50914),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
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
          elevation: 0, // Botones planos como en la foto
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                text,
                style: GoogleFonts.geologica(
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

  void _showErrorSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
  void _showSuccessSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    for (var c in _codeControllers) {
      c.dispose();
    }
    for (var n in _codeFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }
}
