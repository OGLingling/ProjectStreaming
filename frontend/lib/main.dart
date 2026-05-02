import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // 1. Importa Provider

// Asegúrate de que estas rutas sean las correctas en tu proyecto
import 'screens/auth_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/watchlist_providers.dart'; // 2. Importa tu WatchlistProvider
import 'providers/settings_provider.dart'; // 3. Importa tu SettingsProvider

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
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const emeraldWind = Color(0xFF00C853);
    const electricCyan = Color(0xFF00D8FF);
    const darkSurface = Color(0xFF121212);
    const darkSurfaceHigh = Color(0xFF1B1F22);
    const alertRed = Color(0xFFFF5252);

    final baseTextTheme =
        GoogleFonts.openSansTextTheme(ThemeData.dark().textTheme).copyWith(
          headlineLarge: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          titleLarge: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: const TextStyle(color: Colors.white),
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MovieWind | Streaming Premium',

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkSurface,
        primaryColor: emeraldWind,
        textTheme: baseTextTheme,
        colorScheme: const ColorScheme.dark(
          primary: emeraldWind,
          onPrimary: Colors.black,
          secondary: electricCyan,
          onSecondary: Colors.black,
          surface: darkSurface,
          onSurface: Colors.white,
          error: alertRed,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: emeraldWind,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: emeraldWind,
          foregroundColor: Colors.black,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: electricCyan,
          circularTrackColor: Color(0xFF263238),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: electricCyan,
          thumbColor: electricCyan,
          overlayColor: electricCyan.withValues(alpha: 0.18),
          inactiveTrackColor: Colors.white24,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkSurfaceHigh,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white54),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: electricCyan, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: alertRed, width: 1.4),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: alertRed, width: 1.6),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: emeraldWind,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white12,
            disabledForegroundColor: Colors.white38,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: electricCyan),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkSurfaceHigh,
          contentTextStyle: const TextStyle(color: Colors.white),
          actionTextColor: electricCyan,
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
