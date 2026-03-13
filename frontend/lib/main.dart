import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/movies_screen.dart';

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
        ),
      ),

      // 1. Pantalla de inicio
      initialRoute: '/auth',

      // 2. Definición de rutas (Mapeo de nombres a pantallas)
      // He quitado el 'const' aquí para evitar errores si tus pantallas
      // no tienen constructores constantes.
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/profiles': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          return ProfilesScreen(user: args ?? {});
        },
        '/movies': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
          return MoviesScreen(user: args);
        },
      },

      // 3. Manejo de errores de ruta (Por si una ruta no existe)
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => const AuthScreen());
      },
    );
  }
}
