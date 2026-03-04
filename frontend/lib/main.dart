import 'package:flutter/material.dart';
import 'screens/movies_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MovieWind | Streaming Premium',
      theme: ThemeData(
        brightness: Brightness.dark,
        cardColor: const Color(0xFF1A2232),
        scaffoldBackgroundColor: const Color(0xFF121826),
        primaryColor: Colors.blue,
      ),
      home: MoviesScreen(),
    );
  }
}
