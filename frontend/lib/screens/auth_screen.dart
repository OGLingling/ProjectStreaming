import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/api_service.dart';
import '../models/user_model.dart';
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

  final ApiService _apiService = ApiService();

  final List<TextEditingController> _codeControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _codeFocusNodes = List.generate(4, (_) => FocusNode());

  AuthStep _currentStep = AuthStep.registerLanding;
  bool _isLoading = false;

  final String _bgPosters =
      "https://assets.nflxext.com/ffe/siteui/vlv3/f841d4c7-10e1-40af-bcae-07a3f8dc141a/f6bc1730-68f9-4316-b1e8-7133036e4f32/US-en-20220502-popsignuptwoweeks-perspective_alpha_website_medium.jpg";

  // --- LÓGICA DE MANEJO DE PASOS ---
  void _handleAction() {
    setState(() => _isLoading = true);

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;

        // 1. LANDING DE REGISTRO -> PASAR A CONTRASEÑA
        if (_currentStep == AuthStep.registerLanding) {
          if (_emailController.text.isNotEmpty &&
              _emailController.text.contains('@')) {
            _currentStep = AuthStep.registerPassword;
          } else {
            _showErrorSnackBar("Ingresa un email válido para comenzar");
          }
        }
        // 2. CREACIÓN DE CONTRASEÑA -> NAVEGAR A SELECCIÓN DE PLAN
        else if (_currentStep == AuthStep.registerPassword) {
          if (_passwordController.text.length >= 6 &&
              _nameController.text.isNotEmpty) {
            // --- MODIFICACIÓN AQUÍ: Pasamos la contraseña al siguiente paso ---
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlanSelectionScreen(
                  userEmail: _emailController.text,
                  userName: _nameController.text,
                  password:
                      _passwordController.text, // <--- Nueva variable enviada
                ),
              ),
            );
          } else {
            _showErrorSnackBar(
              "Por favor, ingresa tu nombre y una clave de al menos 6 caracteres",
            );
          }
        }
        // 3. LOGIN EMAIL -> PASAR A CÓDIGO DE VERIFICACIÓN
        else if (_currentStep == AuthStep.loginEmail) {
          if (_emailController.text.isNotEmpty &&
              _emailController.text.contains('@')) {
            _currentStep = AuthStep.loginCode;
            _showSuccessSnackBar("Código enviado a ${_emailController.text}");
          } else {
            _showErrorSnackBar("Ingresa un email válido");
          }
        }
        // 4. LOGIN CÓDIGO -> VERIFICAR Y ENTRAR A PERFILES
        else if (_currentStep == AuthStep.loginCode) {
          _verifyAndNavigate();
        }
      });
    });
  }

  // Nueva función para validar el código de 4 dígitos y navegar
  void _verifyAndNavigate() {
    // Unimos los valores de los 4 cuadros
    String code = _codeControllers.map((e) => e.text).join();

    if (code.length == 4) {
      // Simulación: Si el código es 1234, entra.
      if (code == "1234") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilesScreen(
              user: {
                'email': _emailController.text,
                'id': '123',
                'plan': 'estandar',
              },
            ),
          ),
        );
      } else {
        _showErrorSnackBar("Código incorrecto. Intenta con 1234");
      }
    } else {
      _showErrorSnackBar("Ingresa los 4 dígitos");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _codeFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkBg =
        _currentStep == AuthStep.registerLanding ||
        _currentStep == AuthStep.loginEmail ||
        _currentStep == AuthStep.loginCode;

    // hasPosters controla si mostramos el fondo de las películas
    bool hasPosters = isDarkBg;

    return Scaffold(
      backgroundColor: isDarkBg ? const Color(0xFF141414) : Colors.white,
      body: Stack(
        children: [
          if (hasPosters)
            Stack(
              fit: StackFit.expand,
              children: [
                Image.network(_bgPosters, fit: BoxFit.cover),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: Container(color: Colors.black.withOpacity(0.65)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "MOVIEWIND",
            style: TextStyle(
              color: Color(0xFFE50914),
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          if (_currentStep != AuthStep.loginEmail)
            TextButton(
              onPressed: () {
                setState(() {
                  // Si está en login, lo mandamos a registro. Si está en registro, a login.
                  _currentStep = isAtLogin
                      ? AuthStep.registerLanding
                      : AuthStep.loginEmail;
                });
              },
              child: Text(
                isAtLogin ? "Registrarse" : "Iniciar sesión",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
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
        const Text(
          "Ingresa tu info para iniciar sesión",
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "O bien, comienza con una cuenta nueva.",
          style: TextStyle(color: Colors.white70, fontSize: 17),
        ),
        const SizedBox(height: 30),
        _buildInputField(_emailController, "Email o número de celular", true),
        const SizedBox(height: 25),
        _buildMainButton("Continuar"),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            "Obtener ayuda ∨",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCodeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Ingresa el código que enviamos a tu email",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Text(
                _emailController.text,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _currentStep = AuthStep.loginEmail),
              child: const Text(
                "Cambiar",
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) => _buildCodeDigitInput(index)),
        ),
        const SizedBox(height: 25),
        _buildMainButton("Continuar"),
      ],
    );
  }

  Widget _buildRegisterLandingContent() {
    return Column(
      children: [
        const Text(
          "Películas y series ilimitadas y mucho más",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          "A partir de S/ 24.90. Cancela cuando quieras.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
        const SizedBox(height: 30),
        _buildInputField(_emailController, "Email", true),
        const SizedBox(height: 20),
        _buildMainButton("COMENZAR >"),
      ],
    );
  }

  Widget _buildRegisterPasswordContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "PASO 1 DE 3",
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const Text(
          "Crea una contraseña para iniciar tu membresía",
          style: TextStyle(
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

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    bool isDark, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        filled: true,
        fillColor: isDark ? const Color(0xFF333333) : Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildMainButton(String text) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE50914),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildCodeDigitInput(int index) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _codeFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        maxLength: 1,
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: "",
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3)
            _codeFocusNodes[index + 1].requestFocus();
          if (value.isEmpty && index > 0)
            _codeFocusNodes[index - 1].requestFocus();
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
}
