import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Asegúrate de que estas rutas sean las correctas en tu proyecto
import 'screens/auth_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        // Aplicamos Bebas Neue de forma global para títulos si lo deseas
        textTheme: GoogleFonts.openSansTextTheme(
          ThemeData.dark().textTheme,
        ).copyWith(bodyMedium: const TextStyle(color: Colors.white)),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFFE50914),
          surface: Color(0xFF141414),
        ),
      ),

      initialRoute: '/auth',

      routes: {
        '/auth': (context) => const AuthScreen(),

        '/profiles': (context) {
          // Manejo seguro de argumentos para evitar el error de "null as Map"
          final args = ModalRoute.of(context)?.settings.arguments;
          final userData = args is Map<String, dynamic>
              ? args
              : <String, dynamic>{};
          return ProfilesScreen(user: userData);
        },

        '/main': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final userData = args is Map<String, dynamic>
              ? args
              : <String, dynamic>{};
          return MainNavigationScreen(userData: userData);
        },
      },

      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => const AuthScreen());
      },
    );
  }
}
