import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'plan_selection_screen.dart';

enum AuthStep { loginEmail, loginCode, registerLanding, registerPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const String _logoAsset = 'assets/icon/moviewind.png';
  final String _bgPosters = "https://wallpapers.com/images/hd/netflix-background-gs7hjuwvv2g0e9fj.jpg";

  // Controladores
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes = List.generate(4, (_) => FocusNode());

  AuthStep _currentStep = AuthStep.registerLanding;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // ─── LÓGICA DE ACCIÓN ──────────────────────────────────────────────────────

  Future<void> _handleAction() async {
    if (_isLoading) return;

    final email = _emailController.text.trim().toLowerCase();

    if ((_currentStep == AuthStep.registerLanding || _currentStep == AuthStep.loginEmail) &&
        (!email.contains('@') || !email.contains('.'))) {
      _showSnackBar("Ingresa un email válido", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_currentStep == AuthStep.registerLanding || _currentStep == AuthStep.loginEmail) {
        // Verificar si el usuario ya existe en el backend
        final userData = await ApiService.getUserDataByEmail(email);

        if (userData != null && userData['id'] != null) {
          // EXISTE -> Solicitar código OTP para entrar
          final success = await ApiService.sendOTP(email);
          if (success) {
            setState(() => _currentStep = AuthStep.loginCode);
            _showSnackBar("Código enviado a $email");
          } else {
            _showSnackBar("Error al enviar código", isError: true);
          }
        } else {
          // NO EXISTE -> Flujo de registro (Paso 1 de 3)
          setState(() => _currentStep = AuthStep.registerPassword);
        }
      } else if (_currentStep == AuthStep.registerPassword) {
        _procederAlRegistro(email);
      } else if (_currentStep == AuthStep.loginCode) {
        await _verificarOTPyEntrar(email);
      }
    } catch (e) {
      _showSnackBar("Error de conexión", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _procederAlRegistro(String email) {
    final nombre = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (nombre.isEmpty || password.length < 6) {
      _showSnackBar("Nombre requerido y contraseña min. 6 caracteres", isError: true);
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

  Future<void> _verificarOTPyEntrar(String email) async {
    final code = _codeControllers.map((e) => e.text).join();
    if (code.length < 4) return;

    final userData = await ApiService.verifyOTP(email, code);
    if (userData != null && userData['id'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userData['id'].toString());
      await prefs.setBool('is_logged_in', true);
      
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/profiles', (route) => false);
    } else {
      _showSnackBar("Código incorrecto", isError: true);
    }
  }

  // ─── UI BUILDERS ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildStepContent(),
                ),
              ),
            ),
          ),
          if (_isLoading) 
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case AuthStep.registerLanding:
        return _buildEmailStep("Películas y series ilimitadas", "Comenzar");
      case AuthStep.loginEmail:
        return _buildEmailStep("Inicia sesión", "Continuar");
      case AuthStep.registerPassword:
        return _buildRegisterStep();
      case AuthStep.loginCode:
        return _buildOTPStep();
    }
  }

  Widget _buildEmailStep(String title, String buttonText) {
    return Column(
      children: [
        _logo(),
        const SizedBox(height: 30),
        Text(title, textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _textField(_emailController, "Email", inputType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _primaryButton(buttonText, _handleAction),
      ],
    );
  }

  Widget _buildRegisterStep() {
    return Column(
      children: [
        const Text("PASO 1 DE 3", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text("Crea tu cuenta", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _textField(_nameController, "Nombre completo"),
        const SizedBox(height: 12),
        _textField(_passwordController, "Contraseña", isSecret: true),
        const SizedBox(height: 20),
        _primaryButton("Siguiente", _handleAction),
      ],
    );
  }

  Widget _buildOTPStep() {
    return Column(
      children: [
        const Icon(Icons.mark_email_read, color: Colors.red, size: 50),
        const SizedBox(height: 16),
        const Text("Verifica tu código", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (i) => _buildCodeBox(i)),
        ),
        const SizedBox(height: 24),
        _primaryButton("Entrar", _handleAction),
      ],
    );
  }

  // --- COMPONENTES ATÓMICOS ---

  Widget _logo() => Image.asset(_logoAsset, height: 80, errorBuilder: (c, e, s) => const Icon(Icons.movie, color: Colors.red, size: 80));

  Widget _textField(TextEditingController controller, String hint, {bool isSecret = false, TextInputType? inputType}) {
    return TextField(
      controller: controller,
      obscureText: isSecret && _obscurePassword,
      keyboardType: inputType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: isSecret ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ) : null,
      ),
    );
  }

  Widget _primaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    return SizedBox(
      width: 60,
      height: 70,
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _codeFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white.withOpacity(0.1), // CORREGIDO: Usando fillColor
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3) _codeFocusNodes[index + 1].requestFocus();
          if (value.isEmpty && index > 0) _codeFocusNodes[index - 1].requestFocus();
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(image: NetworkImage(_bgPosters), fit: BoxFit.cover, opacity: 0.3),
      ),
    );
  }

  void _showSnackBar(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    for (var c in _codeControllers) {c.dispose();}
    for (var n in _codeFocusNodes) {n.dispose();}
    super.dispose();
  }
}