import 'package:flutter/material.dart';
// Asegúrate de que las rutas de importación coincidan con tu estructura de carpetas
import 'screens/auth_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  // Garantiza que los servicios de Flutter estén listos antes de ejecutar la app
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

      // Configuración de tema oscuro estilo Netflix
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFFE50914),
          surface: Color(0xFF141414),
        ),
        // Tipografía por defecto para toda la app
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
      ),

      // 1. Pantalla de inicio (Login/Registro)
      initialRoute: '/auth',

      // 2. Definición de rutas
      routes: {
        // Pantalla de Autenticación (Login/Registro)
        '/auth': (context) => const AuthScreen(),

        // Pantalla de Selección de Perfiles
        '/profiles': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          return ProfilesScreen(user: args ?? {});
        },

        // Pantalla Principal (Contenedor con BottomNavigationBar)
        '/main': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          return MainNavigationScreen(userData: args);
        },
      },

      // 3. Manejo de errores de ruta (Fallback)
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => const AuthScreen());
      },
    );
  }
}
