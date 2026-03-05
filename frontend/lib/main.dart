import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/movies_screen.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBdewxBXXdjSPGLaXqcPJ5wTaarfCny19Q",
      authDomain: "moviewind-app.firebaseapp.com",
      projectId: "moviewind-app",
      storageBucket: "moviewind-app.firebasestorage.app",
      messagingSenderId: "1009904700256",
      appId: "1:1009904700256:web:ccab301b7eaf38451a6c05",
      measurementId: "G-WE9XTKWD8Q",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error en la autenticación'));
          }
          if (snapshot.hasData) {
            return const MoviesScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}
