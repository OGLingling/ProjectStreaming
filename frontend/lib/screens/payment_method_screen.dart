import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String userEmail, userName, selectedPlan, password;

  const PaymentMethodScreen({super.key, required this.userEmail, required this.userName, required this.selectedPlan, required this.password});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  bool _loading = false;

  Future<void> _finalizarRegistro() async {
    setState(() => _loading = true);
    try {
      // 1. Firebase
      final cred = await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.userEmail, password: widget.password
      );

      // 2. Base de Datos
      final user = await ApiService.registerUser({
        'email': widget.userEmail,
        'name': widget.userName,
        'plan': widget.selectedPlan,
        'firebaseUid': cred.user!.uid,
      });

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', user['id'].toString());
        await prefs.setBool('is_logged_in', true);
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/profiles', (r) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pago")),
      body: Center(
        child: _loading 
          ? const CircularProgressIndicator() 
          : ElevatedButton(onPressed: _finalizarRegistro, child: const Text("Pagar y Activar")),
      ),
    );
  }
}