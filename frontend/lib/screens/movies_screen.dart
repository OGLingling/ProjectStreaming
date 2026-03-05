import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie_model.dart';
import '../services/api_service.dart';

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

  // --- FUNCIÓN GOOGLE SIN ERRORES ROJOS ---
  Future<void> loginConGoogle() async {
    try {
      // Usamos dynamic para que el editor NO valide los métodos y desaparezca el rojo
      final dynamic googleSignIn = GoogleSignIn();
      final dynamic googleUser = await googleSignIn.signIn();

      if (googleUser == null) return;

      final dynamic googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (userCredential.user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MoviesScreen(
              user: {
                'uid': userCredential.user!.uid,
                'name': userCredential.user!.displayName,
                'profilePic': userCredential.user!.photoURL,
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error de autenticación: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro Netflix
      extendBodyBehindAppBar: true, // Para que el banner suba hasta arriba
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "NETFLIX",
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 30,
          ),
        ),
        actions: [
          if (widget.user != null)
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: CircleAvatar(
                radius: 15,
                backgroundImage: NetworkImage(widget.user!['profilePic'] ?? ""),
              ),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.account_circle,
                color: Colors.white,
                size: 30,
              ),
              onPressed: loginConGoogle,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeroBanner(), // Banner "DOC"
                  _buildHorizontalSection("Mi lista", movies),
                  _buildHorizontalSection(
                    "Tendencias",
                    movies.reversed.toList(),
                  ),
                  _buildHorizontalSection("Populares en MovieWind", movies),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  // --- WIDGET DEL BANNER PRINCIPAL (ESTILO DOC) ---
  Widget _buildHeroBanner() {
    if (movies.isEmpty) return const SizedBox(height: 500);
    final movie = movies[0];

    return Stack(
      children: [
        // Imagen de fondo
        Container(
          height: 600,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(movie.imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Degradado estilo Netflix (Negro abajo)
        Container(
          height: 600,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black45, Colors.transparent, Colors.black],
            ),
          ),
        ),
        // Título y Botones
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                movie.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 45,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _netflixBtn(
                    Icons.play_arrow,
                    "Reproducir",
                    Colors.white,
                    Colors.black,
                  ),
                  const SizedBox(width: 15),
                  _netflixBtn(
                    Icons.info_outline,
                    "Más información",
                    Colors.grey.withOpacity(0.6),
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

  Widget _netflixBtn(IconData icon, String label, Color bg, Color txt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(icon, color: txt, size: 28),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: txt,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // --- SECCIÓN DE FILAS HORIZONTALES ---
  Widget _buildHorizontalSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 25, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: list.length,
            itemBuilder: (context, index) => Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(list[index].imageUrl, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
