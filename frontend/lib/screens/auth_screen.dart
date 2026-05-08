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
  static const String _logoAsset = 'assets/icon/moviewind.png';

  // Controladores de texto
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

    // Limpieza de datos inmediata: evitamos espacios y discrepancias de caja
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
        
        // 1. Verificar existencia del usuario
        final userData = await ApiService.getUserDataByEmail(email);

        // Validación estricta para evitar "undefined" o "null" como String
        if (userData != null && 
            userData['id'] != null && 
            userData['id'].toString() != "null") {
          
          // ✅ EXISTE: Solicitar OTP
          await _solicitarOTP(email);
        } else {
          // ❌ NO EXISTE: Ir a flujo de registro
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear(); // Limpieza preventiva de basura local
          setState(() {
            _currentStep = AuthStep.registerPassword;
          });
        }
      } else if (_currentStep == AuthStep.registerPassword) {
        _procederAlRegistro(email);
      } else if (_currentStep == AuthStep.loginCode) {
        await _verificarOTPyEntrar(email);
      }
    } catch (e) {
      debugPrint("AuthError: $e");
      _showErrorSnackBar("Error de conexión. Inténtalo de nuevo.");
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

  Future<void> _solicitarOTP(String email) async {
    final success = await ApiService.sendOTP(email);

    if (!mounted) return;

    if (success) {
      setState(() => _currentStep = AuthStep.loginCode);
      _showSuccessSnackBar("Código enviado a $email");
    } else {
      _showErrorSnackBar("No se pudo enviar el código. Reintenta.");
    }
  }

  Future<void> _verificarOTPyEntrar(String email) async {
    final String code = _codeControllers.map((e) => e.text).join();

    if (code.length < 4) {
      _showErrorSnackBar("Ingresa el código completo");
      return;
    }

    try {
      final userData = await ApiService.verifyOTP(email, code);

      if (!mounted) return;

      if (userData != null && userData['id'] != null) {
        await _guardarSesionYNavegar(userData);
      } else {
        _showErrorSnackBar("Código incorrecto o expirado");
      }
    } catch (e) {
      _showErrorSnackBar("Error al verificar el código");
    }
  }

  Future<void> _guardarSesionYNavegar(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Aseguramos persistencia de datos limpios
      final String userId = userData['id'].toString();
      final String userEmail = userData['email']?.toString() ?? _emailController.text.trim();

      await prefs.setString('user_id', userId);
      await prefs.setString('user_email', userEmail);
      await prefs.setBool('is_logged_in', true);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/profiles',
        (route) => false,
        arguments: userData,
      );
    } catch (e) {
      _showErrorSnackBar("Error al iniciar sesión localmente");
    }
  }

  // ─── UI BUILDING ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _buildModernBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + keyboardBottom),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 430),
                              child: _buildStepContent(),
                            ),
                          ),
                        ),
                      );
                    },
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
          errorBuilder: (c, e, s) => Container(color: const Color(0xFF121212)),
        ),
        Container(color: const Color(0xFF121212).withOpacity(0.70)),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF121212).withOpacity(0.96),
                const Color(0xFF121212).withOpacity(0.74),
                const Color(0xFF121212).withOpacity(0.98),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final bool isAtLogin = _currentStep == AuthStep.loginEmail || _currentStep == AuthStep.loginCode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "MovieWind",
            style: GoogleFonts.montserrat(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          if (_currentStep == AuthStep.registerLanding || isAtLogin)
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: isAtLogin ? Colors.white.withOpacity(0.08) : theme.colorScheme.primary,
                foregroundColor: isAtLogin ? theme.colorScheme.secondary : theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isAtLogin ? theme.colorScheme.secondary.withOpacity(0.42) : Colors.transparent),
                ),
              ),
              onPressed: () {
                setState(() {
                  _currentStep = isAtLogin ? AuthStep.registerLanding : AuthStep.loginEmail;
                });
              },
              child: Text(isAtLogin ? "Regístrate" : "Iniciar sesión"),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case AuthStep.registerLanding: return _buildRegisterLanding();
      case AuthStep.loginEmail: return _buildLoginEmail();
      case AuthStep.registerPassword: return _buildRegisterPassword();
      case AuthStep.loginCode: return _buildLoginCode();
    }
  }

  Widget _buildLogoMark({double size = 112}) {
    return Image.asset(
      _logoAsset,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.movie_filter_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: size * 0.72,
      ),
    );
  }

  Widget _buildRegisterLanding() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogoMark(size: 118),
        const SizedBox(height: 28),
        Text("Películas y series ilimitadas", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text("Streaming premium con el impulso de MovieWind.", textAlign: TextAlign.center, style: GoogleFonts.geologica(color: Colors.white.withOpacity(0.78), fontSize: 16)),
        const SizedBox(height: 28),
        _buildAuthTextField(_emailController, "Email", keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildAuthButton("Comenzar", _handleAction),
        const SizedBox(height: 12),
        Text("A partir de S/ 24.90. Cancela cuando quieras.", style: GoogleFonts.geologica(color: Theme.of(context).colorScheme.secondary.withOpacity(0.86), fontSize: 13)),
      ],
    );
  }

  Widget _buildLoginEmail() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _buildLogoMark(size: 104)),
        const SizedBox(height: 30),
        Text("Inicia sesión", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildAuthTextField(_emailController, "Email", keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 18),
        _buildAuthButton("Continuar", _handleAction),
      ],
    );
  }

  Widget _buildRegisterPassword() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _buildLogoMark(size: 98)),
        const SizedBox(height: 28),
        Text("PASO 1 DE 3", textAlign: TextAlign.center, style: GoogleFonts.geologica(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text("Crea tu acceso MovieWind", textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildAuthTextField(_nameController, "Nombre completo"),
        const SizedBox(height: 16),
        _buildAuthTextField(_passwordController, "Contraseña", isPassword: true),
        const SizedBox(height: 26),
        _buildAuthButton("Siguiente", _handleAction),
      ],
    );
  }

  Widget _buildLoginCode() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogoMark(size: 96),
        const SizedBox(height: 22),
        Icon(Icons.mark_email_read_outlined, color: Theme.of(context).colorScheme.secondary, size: 44),
        const SizedBox(height: 16),
        Text("Verifica tu código", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text("Enviamos un código de 4 dígitos a\n${_emailController.text.trim()}", textAlign: TextAlign.center, style: GoogleFonts.geologica(color: Colors.white.withOpacity(0.72), fontSize: 14)),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(4, (i) => _buildCodeBox(i))),
        const SizedBox(height: 28),
        _buildAuthButton("Entrar", _handleAction),
        const SizedBox(height: 14),
        TextButton(onPressed: _isLoading ? null : () => _solicitarOTP(_emailController.text.trim().toLowerCase()), child: const Text("¿No recibiste el código? Reenviar")),
      ],
    );
  }

  Widget _buildAuthTextField(TextEditingController controller, String hint, {bool isPassword = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? _obscurePassword : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: hint,
        suffixIcon: isPassword ? IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white60), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null,
      ),
    );
  }

  Widget _buildAuthButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6)) : Text(text),
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    return SizedBox(
      width: 68,
      height: 68,
      child: TextField(
        controller: _codeControllers[index],
        focusNode: _codeFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        maxLength: 1,
        decoration: InputDecoration(counterText: "", filled: true, fillColor: Colors.white.withOpacity(0.08), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
        onChanged: (v) {
          if (v.isNotEmpty && index < 3) _codeFocusNodes[index + 1].requestFocus();
          if (v.isEmpty && index > 0) _codeFocusNodes[index - 1].requestFocus();
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.primary, behavior: SnackBarBehavior.floating));
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