import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart'
    as firebase_auth; // Alias para evitar conflictos
import 'package:google_sign_in/google_sign_in.dart';
import '../models/movie_model.dart';
import '../services/api_service.dart';
import 'auth_screen.dart'; // Asegúrate de importar tu AuthScreen

class MoviesScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const MoviesScreen({super.key, this.user});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  final ApiService _apiService = ApiService();
  List<Movie> movies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMovies();
  }

  Future<void> _fetchMovies() async {
    try {
      final response = await http.get(
        Uri.parse('${_apiService.baseUrl}/movies'),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          movies = data.map((m) => Movie.fromJson(m)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // MÉTODO PARA CERRAR SESIÓN (TEMPORAL)
  Future<void> _signOut() async {
    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
      // Si usas Google Sign In, también deberías desconectarlo
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    } catch (e) {
      debugPrint("Error al cerrar sesión: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(
          0.5,
        ), // Un poco de sombra para legibilidad
        elevation: 0,
        title: const Text(
          "MOVIEWIND",
          style: TextStyle(
            color: Color(0xFFE50914),
            fontWeight: FontWeight.bold,
            fontSize: 26,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          // BOTÓN DE CIERRE DE SESIÓN TEMPORAL
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: "Cerrar Sesión",
            onPressed: _signOut,
          ),
          if (widget.user != null)
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: Colors.red,
                backgroundImage: widget.user!['profilePic'] != null
                    ? NetworkImage(widget.user!['profilePic'])
                    : null,
                child: widget.user!['profilePic'] == null
                    ? const Icon(Icons.person, size: 20, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeroBanner(),
                  _buildHorizontalSection("Mi lista", movies),
                  _buildHorizontalSection(
                    "Tendencias ahora",
                    movies.reversed.toList(),
                  ),
                  _buildHorizontalSection("Originales de MovieWind", movies),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  // --- Los widgets de _buildHeroBanner, _actionBtn y _buildHorizontalSection se mantienen igual ---
  Widget _buildHeroBanner() {
    if (movies.isEmpty) return const SizedBox(height: 500);
    final movie = movies[0];

    return Stack(
      children: [
        Container(
          height: 550,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(movie.imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          height: 550,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black],
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                movie.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionBtn(
                    Icons.play_arrow,
                    "Ver ahora",
                    Colors.white,
                    Colors.black,
                  ),
                  const SizedBox(width: 12),
                  _actionBtn(
                    Icons.add,
                    "Mi lista",
                    Colors.grey[800]!.withOpacity(0.8),
                    Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, Color bg, Color txt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Icon(icon, color: txt, size: 24),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: txt,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15, top: 20, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 15),
            itemCount: list.length,
            itemBuilder: (context, index) => Container(
              width: 125,
              margin: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Image.network(
                  list[index].imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.grey[900]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
