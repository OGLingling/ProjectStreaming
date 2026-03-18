import 'package:flutter/material.dart';

class SeriesScreen extends StatelessWidget {
  const SeriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF141414),
      body: Center(
        child: Text(
          "Sección de Series",
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
