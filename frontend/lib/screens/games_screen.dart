import 'package:flutter/material.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF141414),
      body: Center(
        child: Text(
          "Sección de Juegos",
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
