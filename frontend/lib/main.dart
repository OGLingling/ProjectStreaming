import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // 1. Importa Provider

// Asegúrate de que estas rutas sean las correctas en tu proyecto
import 'screens/auth_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/watchlist_providers.dart'; // 2. Importa tu WatchlistProvider
import 'providers/subtitle_provider.dart'; // 3. Importa tu SubtitleProvider

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBdewxBXXdjSPGLaXqcPJ5wTaarfCny19Q",
        authDomain: "moviewind-app.firebaseapp.com",
        projectId: "moviewind-app",
        storageBucket: "moviewind-app.firebasestorage.app",
        messagingSenderId: "1009904700256",
        appId: "1:1009904700256:web:ccab301b7eaf38451a6c05",
      ),
    );
  } catch (e) {
    debugPrint("Firebase ya estaba inicializado o error: $e");
  }

  // 3. Envolvemos la App con MultiProvider
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WatchlistProvider()),
        ChangeNotifierProvider(create: (_) => SubtitleProvider()),
      ],
      child: const MyApp(),
    ),
  );
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
