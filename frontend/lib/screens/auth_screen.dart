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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes = List.generate(4, (_) => FocusNode());

  AuthStep _currentStep = AuthStep.registerLanding;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleAction() async {
    if (_isLoading) return;
    final email = _emailController.text.trim().toLowerCase();

    if ((_currentStep == AuthStep.registerLanding || _currentStep == AuthStep.loginEmail) && 
        (!email.contains('@') || email.length < 5)) {
      _showSnackBar("Email inválido", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_currentStep == AuthStep.registerLanding || _currentStep == AuthStep.loginEmail) {
        // CORRECCIÓN CLAVE: Verificación real antes de decidir flujo
        final userData = await ApiService.getUserDataByEmail(email);

        if (userData != null && userData['id'] != null) {
          // Existe -> Login con OTP
          final ok = await ApiService.sendOTP(email);
          if (ok) setState(() => _currentStep = AuthStep.loginCode);
        } else {
          // No existe -> Registro
          setState(() => _currentStep = AuthStep.registerPassword);
        }
      } else if (_currentStep == AuthStep.registerPassword) {
        _procederAlRegistro(email);
      } else if (_currentStep == AuthStep.loginCode) {
        _verificarEntrar(email);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _procederAlRegistro(String email) {
    if (_nameController.text.isEmpty || _passwordController.text.length < 6) {
      _showSnackBar("Datos incompletos o contraseña corta", isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => PlanSelectionScreen(
        userEmail: email, userName: _nameController.text, password: _passwordController.text,
      )),
    );
  }

  Future<void> _verificarEntrar(String email) async {
    final code = _codeControllers.map((e) => e.text).join();
    final user = await ApiService.verifyOTP(email, code);
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user['id'].toString());
      await prefs.setBool('is_logged_in', true);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/profiles', (r) => false);
    } else {
      _showSnackBar("Código incorrecto", isError: true);
    }
  }

  // --- UI BUILDERS (Indispensables para que no de error) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(child: Center(child: SingleChildScrollView(child: _buildStepContent()))),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case AuthStep.registerLanding: return _stepEmail("Bienvenido a MovieWind", "Comenzar");
      case AuthStep.loginEmail: return _stepEmail("Inicia Sesión", "Continuar");
      case AuthStep.registerPassword: return _stepRegister();
      case AuthStep.loginCode: return _stepOTP();
    }
  }

  Widget _stepEmail(String title, String btnText) {
    return Column(children: [
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 20),
      _input(_emailController, "Email"),
      const SizedBox(height: 10),
      _button(btnText, _handleAction),
    ]);
  }

  Widget _stepRegister() {
    return Column(children: [
      const Text("Crea tu cuenta", style: TextStyle(color: Colors.white, fontSize: 22)),
      _input(_nameController, "Nombre completo"),
      _input(_passwordController, "Contraseña", isPass: true),
      _button("Siguiente", _handleAction),
    ]);
  }

  Widget _stepOTP() {
    return Column(children: [
      const Text("Introduce el código", style: TextStyle(color: Colors.white)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) => _box(i))),
      _button("Verificar", _handleAction),
    ]);
  }

  Widget _input(TextEditingController c, String h, {bool isPass = false}) => Padding(
    padding: const EdgeInsets.all(8.0),
    child: TextField(controller: c, obscureText: isPass, decoration: InputDecoration(hintText: h, filled: true, fillColor: Colors.white)),
  );

  Widget _button(String t, VoidCallback f) => ElevatedButton(onPressed: f, child: Text(t));

  Widget _box(int i) => Container(
    width: 50, margin: const EdgeInsets.all(5),
    child: TextField(
      controller: _codeControllers[i], focusNode: _codeFocusNodes[i],
      textAlign: TextAlign.center, maxLength: 1, decoration: const InputDecoration(counterText: "", fillBy: Colors.white),
      onChanged: (v) => (v.isNotEmpty && i < 3) ? _codeFocusNodes[i+1].requestFocus() : null,
    ),
  );

  Widget _buildBackground() => Container(color: Colors.black87);

  void _showSnackBar(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? Colors.red : Colors.green));
  }
}