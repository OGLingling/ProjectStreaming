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
  // ✅ CAMBIO #1: State<AuthScreen> en lugar de _AuthScreenState
  // El tipo privado _AuthScreenState causará un warning en versiones recientes
  // de Flutter porque la clase State debe usar el tipo público del widget.
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

  // ✅ CAMBIO #2: Variable de visibilidad de contraseña
  // Antes la contraseña era siempre oculta sin opción de verla.
  // Es una buena práctica de UX permitir mostrarla/ocultarla.
  bool _obscurePassword = true;

  final String _bgPosters =
      "https://wallpapers.com/images/hd/netflix-background-gs7hjuwvv2g0e9fj.jpg";

  // ─── LÓGICA PRINCIPAL ───────────────────────────────────────────────────────

  Future<void> _handleAction() async {
    if (_isLoading) return;

    if ((_currentStep == AuthStep.registerLanding ||
            _currentStep == AuthStep.loginEmail) &&
        !_emailController.text.contains('@')) {
      _showErrorSnackBar("Ingresa un email válido");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_currentStep == AuthStep.registerLanding) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        setState(() => _currentStep = AuthStep.registerPassword);
      } else if (_currentStep == AuthStep.registerPassword) {
        // ✅ CAMBIO #3: Validación con trim() para evitar espacios accidentales
        // Sin trim(), un nombre como "  " (espacios) pasaba la validación
        // de isNotEmpty, creando usuarios con nombre en blanco.
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

        // ✅ CAMBIO #4: SE PASA 'password' A PlanSelectionScreen
        // ESTE ERA EL ERROR PRINCIPAL. PlanSelectionScreen ahora tiene
        // 'password' como parámetro required (lo agregamos en la corrección
        // anterior). Al no pasarlo aquí, Flutter lanzaba un error de compilación:
        // "The named parameter 'password' is required but there's no
        // corresponding argument."
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlanSelectionScreen(
              userEmail: _emailController.text.trim(),
              userName: nombre,
              password: password, // ✅ CORRECCIÓN CRÍTICA
            ),
          ),
        );
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

  // ─── LÓGICA DE LOGIN ─────────────────────────────────────────────────────────

  Future<void> _solicitarOTP() async {
    final success = await ApiService.sendOTP(_emailController.text.trim());
    if (!mounted) return;

    if (success) {
      setState(() => _currentStep = AuthStep.loginCode);
      _showSuccessSnackBar("Código enviado a ${_emailController.text.trim()}");
    } else {
      _showErrorSnackBar(
        "El correo no está registrado. Vamos a crear tu cuenta.",
      );
      setState(() => _currentStep = AuthStep.registerPassword);
    }
  }

  Future<void> _verificarOTPyEntrar() async {
    final String code = _codeControllers.map((e) => e.text).join();

    if (code.length < 4) {
      _showErrorSnackBar("Por favor, ingresa el código de 4 dígitos");
      // ✅ CAMBIO #5: return temprano antes del setState de loading
      // En el original, la validación estaba DENTRO del bloque try pero
      // DESPUÉS de setState(_isLoading = true), dejando el botón bloqueado
      // si el usuario no había llenado todos los dígitos.
      return;
    }

    // El setState de loading ya lo maneja _handleAction en el bloque principal.
    // No hace falta repetirlo aquí.
    try {
      final userData = await ApiService.verifyOTP(
        _emailController.text.trim(),
        code,
      );

      if (!mounted) return;

      if (userData != null) {
        await _guardarSesionYNavegar(userData);
      } else {
        _showErrorSnackBar("Código incorrecto o expirado");
      }
    } catch (e) {
      if (mounted)
        _showErrorSnackBar("Error de conexión al verificar el código");
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

  // ─── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isDarkBg = _currentStep != AuthStep.registerPassword;

    return Scaffold(
      backgroundColor: isDarkBg ? Colors.black : Colors.white,
      // ✅ CAMBIO #6: resizeToAvoidBottomInset: false para que el teclado
      // no empuje el contenido y deforme el fondo de pantalla en pasos oscuros.
      resizeToAvoidBottomInset: false,
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
                      // ✅ CAMBIO #7: padding bottom para no tapar el botón con el teclado
                      padding: const EdgeInsets.fromLTRB(25, 0, 25, 40),
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
            fontSize: 38,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "A partir de S/ 24.90. Cancela cuando quieras.",
          style: GoogleFonts.geologica(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 25),
        Text(
          "¿Quieres ver MovieWind ya? Ingresa tu email para crear una cuenta.",
          textAlign: TextAlign.center,
          style: GoogleFonts.geologica(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 10),
        Text(
          "Usa tu correo para entrar a tu cuenta.",
          style: GoogleFonts.geologica(color: Colors.white70),
        ),
        const SizedBox(height: 30),
        _buildNetflixTextField(_emailController, "Email o número de celular"),
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
            fontSize: 28,
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
        // ✅ CAMBIO #8: Se pasa obscurePassword al campo de contraseña
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
        // ✅ CAMBIO #9: Mostrar el email al que se envió el código
        // Antes el usuario no sabía a qué correo había llegado el OTP.
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
        // ✅ CAMBIO #10: Botón para reenviar código
        // Antes no había forma de reenviar el OTP si no llegaba.
        TextButton(
          onPressed: _isLoading ? null : _solicitarOTP,
          child: Text(
            "¿No recibiste el código? Reenviar",
            style: GoogleFonts.geologica(
              color: Colors.white60,
              fontSize: 13,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white60,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetflixTextField(
    TextEditingController controller,
    String hint, {
    bool isDark = true,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      // ✅ CAMBIO #11: Soporte para mostrar/ocultar contraseña
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isPassword
          ? TextInputType.visiblePassword
          : (hint.toLowerCase().contains('email')
                ? TextInputType.emailAddress
                : TextInputType.text),
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        filled: true,
        fillColor: isDark ? Colors.grey[900]!.withOpacity(0.85) : Colors.white,
        // ✅ Ícono de ojo para mostrar/ocultar contraseña
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              )
            : null,
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
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
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
          if (v.isEmpty && index > 0) {
            _codeFocusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

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

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    for (final c in _codeControllers) c.dispose();
    for (final n in _codeFocusNodes) n.dispose();
    super.dispose();
  }
}
