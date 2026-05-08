import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'profiles_screen.dart';
import '../models/user_model.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String selectedPlan;
  final String password;

  const PaymentMethodScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.selectedPlan,
    required this.password,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  bool _isLoading = false;

  Future<void> _procesarRegistro(BuildContext context) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    firebase_auth.UserCredential? userCredential;

    try {
      // PASO 1: REGISTRO EN FIREBASE
      userCredential = await firebase_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: widget.userEmail.trim(),
            password: widget.password.trim(),
          );

      final String firebaseUid = userCredential.user!.uid;

      // PASO 2: REGISTRO EN BASE DE DATOS (Neon/Prisma)
      // ✅ CORRECCIÓN: Ahora pasamos un solo MAPA como argumento posicional
      final userData = await ApiService.registerUser({
        'email': widget.userEmail.trim(),
        'name': widget.userName.trim(),
        'plan': widget.selectedPlan,
        'password': widget.password.trim(),
        'firebaseUid': firebaseUid, // Útil para vincular ambas cuentas
      });

      if (userData == null) {
        throw Exception("API_ERROR");
      }

      final String dbUserId = userData['id']?.toString() ?? firebaseUid;

      // PASO 3: ENVÍO DEL CÓDIGO OTP
      await ApiService.sendOTP(widget.userEmail.trim());

      // PASO 4: PERSISTENCIA LOCAL
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', dbUserId);
      await prefs.setString('firebase_uid', firebaseUid);
      await prefs.setBool('is_logged_in', true);

      // PASO 5: NAVEGACIÓN
      final User nuevoUsuario = User(
        id: dbUserId,
        name: widget.userName,
        email: widget.userEmail,
        plan: widget.selectedPlan,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilesScreen(user: nuevoUsuario.toJson()),
        ),
        (route) => false,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (userCredential != null) {
        await userCredential.user?.delete();
      }

      String errorMsg = "Error al registrar: ${e.code}";
      if (e.code == 'email-already-in-use') {
        errorMsg = "El correo ya está registrado.";
      } else if (e.code == 'weak-password') {
        errorMsg = "La contraseña es demasiado débil.";
      }

      if (mounted) _showError(context, errorMsg);
    } catch (e) {
      if (userCredential != null) {
        await userCredential.user?.delete();
      }
      if (mounted) {
        final String mensaje = e.toString().contains("API_ERROR")
            ? "No se pudo conectar con el servidor de la base de datos."
            : "Hubo un error al crear tu cuenta. Intenta de nuevo.";
        _showError(context, mensaje);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        automaticallyImplyLeading: !_isLoading,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFE50914),
                  size: 50,
                ),
                const SizedBox(height: 15),
                const Text(
                  "PASO 3 DE 3",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Configura tu pago",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: Text(
                    "Al seleccionar un método, completarás tu registro y activaremos tu cuenta.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
                _buildPaymentOption(
                  title: "Tarjeta de crédito o débito",
                  icons: [Icons.credit_card, Icons.account_balance_wallet],
                  onTap: () => _procesarRegistro(context),
                ),
                _buildPaymentOption(
                  title: "Código de regalo",
                  icons: [Icons.card_giftcard],
                  onTap: () => _procesarRegistro(context),
                ),
                const SizedBox(height: 40),
                const Text(
                  "Seguridad de nivel bancario 🔒",
                  style: TextStyle(color: Colors.black38, fontSize: 13),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFE50914)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required List<IconData> icons,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 22),
        decoration: BoxDecoration(
          border: Border.all(
            color: _isLoading ? Colors.grey.shade200 : Colors.grey.shade300,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _isLoading ? Colors.grey.shade400 : Colors.black,
                ),
              ),
            ),
            ...icons.map((icon) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(icon,
                      color: _isLoading ? Colors.grey.shade300 : Colors.blueGrey),
                )),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_ios,
                size: 18,
                color: _isLoading ? Colors.grey.shade300 : Colors.black45),
          ],
        ),
      ),
    );
  }
}