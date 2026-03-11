import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profiles_screen.dart';

class VerifyPinScreen extends StatefulWidget {
  final Map<String, dynamic> user; // Recibimos los datos del usuario logueado

  const VerifyPinScreen({super.key, required this.user});

  @override
  State<VerifyPinScreen> createState() => _VerifyPinScreenState();
}

class _VerifyPinScreenState extends State<VerifyPinScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  Timer? _timer;
  int _start = 900; // 15 minutos en segundos (15 * 60)

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() => timer.cancel());
      } else {
        setState(() => _start--);
      }
    });
  }

  String get _timerText {
    int minutes = _start ~/ 60;
    int seconds = _start % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyOtp() async {
    String enteredPin = _controllers.map((c) => c.text).join();
    if (enteredPin.length < 4) return;

    final supabase = Supabase.instance.client;

    try {
      // 1. Consultar el PIN y la expiración real en Neon/Supabase
      final data = await supabase
          .from('User')
          .select('pin, pinExpiresAt')
          .eq('email', widget.user['email'])
          .single();

      String? correctPin = data['pin'];
      DateTime expiresAt = DateTime.parse(data['pinExpiresAt']);

      // 2. Validaciones
      if (DateTime.now().isAfter(expiresAt)) {
        _showError("El código ha expirado. Solicita uno nuevo.");
        return;
      }

      if (enteredPin == correctPin) {
        // PIN Correcto -> Marcar como verificado y entrar
        await supabase
            .from('User')
            .update({'isVerified': true})
            .eq('email', widget.user['email']);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilesScreen(user: widget.user),
          ),
        );
      } else {
        _showError("PIN incorrecto. Revisa tu correo.");
      }
    } catch (e) {
      _showError("Error al verificar: $e");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Verifica tu cuenta",
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Enviamos un PIN a ${widget.user['email']}",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 30),

              // Celdas del PIN
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) => _buildPinBox(index)),
              ),

              const SizedBox(height: 30),
              Text(
                "El código expira en: $_timerText",
                style: TextStyle(
                  color: _start < 60 ? Colors.red : Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 50),

              ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  "VERIFICAR Y ENTRAR",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinBox(int index) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(color: Colors.white, fontSize: 24),
        decoration: InputDecoration(
          counterText: "",
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (index == 3 && value.isNotEmpty) _verifyOtp();
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}
