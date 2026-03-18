import 'package:flutter/material.dart';

class PeliculasScreen extends StatelessWidget {
  const PeliculasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF141414),
      body: Center(
        child: Text(
          "Sección de Películas",
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
