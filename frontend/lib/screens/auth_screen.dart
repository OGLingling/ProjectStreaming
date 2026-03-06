import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart'; // Importante añadir esto
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'profiles_screen.dart';
import 'plan_selection_screen.dart';

enum AuthStep {
  loginEmail,
  loginCode,
  profileSelection,
  registerLanding,
  registerPassword,
}

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

  void _handleAction() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_currentStep == AuthStep.registerLanding) {
          if (_emailController.text.isNotEmpty &&
              _emailController.text.contains('@')) {
            _currentStep = AuthStep.registerPassword;
          } else {
            _showErrorSnackBar("Ingresa un email válido para comenzar");
          }
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
            _showErrorSnackBar(
              "Ingresa tu nombre y una clave de al menos 6 caracteres",
            );
          }
        } else if (_currentStep == AuthStep.loginEmail) {
          if (_emailController.text.isNotEmpty &&
              _emailController.text.contains('@')) {
            _currentStep = AuthStep.loginCode;
            _showSuccessSnackBar("Código enviado a ${_emailController.text}");
          } else {
            _showErrorSnackBar("Ingresa un email válido");
          }
        } else if (_currentStep == AuthStep.loginCode) {
          _verifyAndNavigate();
        }
      });
    });
  }

  void _verifyAndNavigate() async {
    // Añadimos async
    String code = _codeControllers.map((e) => e.text).join();

    if (code == "1234") {
      setState(() => _isLoading = true);

      try {
        final user = await ApiService.getUserByEmail(_emailController.text);

        if (!mounted) return;

        if (user != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilesScreen(
                user: {
                  'email': user.email,
                  'id': user.id,
                  'plan':
                      user.plan, // Aquí ya vendrá 'Básico', 'Estándar', etc.
                  'name': user.name,
                },
              ),
            ),
          );
        } else {
          _showErrorSnackBar("No se encontró una cuenta con este email.");
        }
      } catch (e) {
        _showErrorSnackBar("Error al conectar con el servidor.");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      _showErrorSnackBar("Código incorrecto. Intenta con 1234");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    for (var c in _codeControllers) c.dispose();
    for (var n in _codeFocusNodes) n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkBg =
        _currentStep == AuthStep.registerLanding ||
        _currentStep == AuthStep.loginEmail ||
        _currentStep == AuthStep.loginCode;

    double horizontalPadding = _currentStep == AuthStep.registerLanding
        ? 45
        : 25;

    return Scaffold(
      backgroundColor: isDarkBg ? const Color(0xFF141414) : Colors.white,
      body: Stack(
        children: [
          if (isDarkBg)
            Stack(
              fit: StackFit.expand,
              children: [
                Image.network(_bgPosters, fit: BoxFit.cover),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: Container(color: Colors.black.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDarkBg),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
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

  Widget _buildHeader(bool isDark) {
    bool isAtLogin =
        _currentStep == AuthStep.loginEmail ||
        _currentStep == AuthStep.loginCode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "MOVIEWIND",
            style: GoogleFonts.montserrat(
              // Usamos Montserrat para el logo
              color: const Color(0xFFE50914),
              fontSize: 24,
              fontWeight: FontWeight.w900, // Peso extra para el logo
              letterSpacing: 1.2,
            ),
          ),
          TextButton(
            onPressed: () => setState(
              () => _currentStep = isAtLogin
                  ? AuthStep.registerLanding
                  : AuthStep.loginEmail,
            ),
            child: Text(
              isAtLogin ? "Registrarse" : "Iniciar sesión",
              style: GoogleFonts.geologica(
                // Usamos Geologica para UI
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case AuthStep.loginEmail:
        return _buildLoginEmailContent();
      case AuthStep.loginCode:
        return _buildLoginCodeContent();
      case AuthStep.registerLanding:
        return _buildRegisterLandingContent();
      case AuthStep.registerPassword:
        return _buildRegisterPasswordContent();
      default:
        return _buildLoginEmailContent();
    }
  }

  Widget _buildLoginEmailContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Inicia sesión",
          style: GoogleFonts.montserrat(
            // Montserrat para títulos
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Ingresa tu email para continuar.",
          style: GoogleFonts.geologica(
            color: Colors.white70,
            fontSize: 17,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 30),
        _buildInputField(_emailController, "Email", true),
        const SizedBox(height: 15),
        _buildMainButton("Continuar"),
        const SizedBox(height: 20),
        PopupMenuButton<String>(
          color: const Color(0xFF222222),
          offset: const Offset(0, 40),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'soporte',
              child: Text(
                'Centro de ayuda',
                style: GoogleFonts.geologica(color: Colors.white),
              ),
            ),
            PopupMenuItem(
              value: 'terminos',
              child: Text(
                'Términos de uso',
                style: GoogleFonts.geologica(color: Colors.white),
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Obtener ayuda ∨",
              style: GoogleFonts.geologica(color: Colors.white70, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterLandingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Películas y series ilimitadas y mucho más",
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "Disfruta donde quieras. Cancela en cualquier momento.",
          textAlign: TextAlign.center,
          style: GoogleFonts.geologica(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 25),
        Text(
          "¿Quieres ver MovieWind ya? Ingresa tu email para crear una cuenta.",
          textAlign: TextAlign.center,
          style: GoogleFonts.geologica(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _emailController,
                  style: GoogleFonts.geologica(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: GoogleFonts.geologica(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.5),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _isLoading ? null : _handleAction,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Comenzar",
                              style: GoogleFonts.geologica(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 24),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterPasswordContent() {
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
          "Crea tu cuenta",
          style: GoogleFonts.montserrat(
            color: Colors.black,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        _buildInputField(_nameController, "Nombre", false),
        const SizedBox(height: 15),
        _buildInputField(
          _passwordController,
          "Contraseña",
          false,
          isPassword: true,
        ),
        const SizedBox(height: 25),
        _buildMainButton("CONTINUAR"),
      ],
    );
  }

  Widget _buildLoginCodeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Verifica tu cuenta",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Enviamos un código a ${_emailController.text}",
          style: GoogleFonts.geologica(color: Colors.white70),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (i) => _buildCodeDigitInput(i)),
        ),
        const SizedBox(height: 30),
        _buildMainButton("Verificar"),
      ],
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    bool isDark, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.geologica(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.geologica(
          color: isDark ? Colors.white60 : Colors.black54,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF333333) : Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ),
      ),
    );
  }

  Widget _buildMainButton(String text) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE50914),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: _isLoading ? null : _handleAction,
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
                text,
                style: GoogleFonts.geologica(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildCodeDigitInput(int index) {
    return Container(
      width: 60,
      height: 65,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _codeFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: GoogleFonts.geologica(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        maxLength: 1,
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: "",
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 3)
            _codeFocusNodes[index + 1].requestFocus();
          if (v.isEmpty && index > 0) _codeFocusNodes[index - 1].requestFocus();
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.geologica()),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.geologica()),
        backgroundColor: Colors.green,
      ),
    );
  }
}
