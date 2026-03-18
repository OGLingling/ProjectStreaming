import 'package:flutter/material.dart';

class NovedadesScreen extends StatelessWidget {
  const NovedadesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF141414),
      body: Center(
        child: Text(
          "Sección de Novedades",
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
