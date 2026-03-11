import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'
    as firebase_auth; // Importamos Firebase
import '../services/api_service.dart'; // Asegúrate de que la ruta sea correcta
import 'profiles_screen.dart';
import '../models/user_model.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String password; // <--- Ahora recibimos la contraseña
  final String selectedPlan;

  const PaymentMethodScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.password,
    required this.selectedPlan,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  // --- FUNCIÓN PARA REGISTRO REAL (FIREBASE + NEON) ---
  void _procesarRegistro(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Firebase
      final firebase_auth.UserCredential userCredential = await firebase_auth
          .FirebaseAuth
          .instance
          .createUserWithEmailAndPassword(
            email: widget.userEmail,
            password: widget.password,
          );

      User nuevoUsuario = User(
        id: userCredential.user!.uid,
        name: widget.userName,
        email: widget.userEmail,
        password: widget.password,
        plan: widget.selectedPlan,
      );

      await ApiService.registerUser(
        widget.userEmail,
        widget.userName,
        widget.password,
        widget.selectedPlan,
      );

      // Navegación
      if (!mounted) return;
      Navigator.pop(context);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilesScreen(user: nuevoUsuario.toJson()),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError(context, "Error: $e");
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.lock_outline, color: Color(0xFFE50914), size: 50),
          const SizedBox(height: 10),
          const Text(
            "PASO 3 DE 3",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Configura tu pago",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "Al seleccionar un método, completarás tu registro y podrás crear tus perfiles.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),

          _buildPaymentOption(
            title: "Tarjeta de crédito o débito",
            icons: [Icons.credit_card, Icons.payment],
            onTap: () => _procesarRegistro(context),
          ),
          _buildPaymentOption(
            title: "Código de regalo",
            icons: [Icons.card_giftcard],
            onTap: () => _procesarRegistro(context),
          ),

          const Spacer(),
          const Text(
            "Seguridad de nivel bancario",
            style: TextStyle(color: Colors.black38, fontSize: 12),
          ),
          const SizedBox(height: 20),
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
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
            ...icons.map((icon) => Icon(icon, color: Colors.blueGrey)).toList(),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}
