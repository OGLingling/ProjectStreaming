import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movie_model.dart';
import 'movie_details_screen.dart';

class MoviesScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const MoviesScreen({super.key, this.user});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  List<Movie> movies = [];
  bool isLoading = true;
  String? errorMessage;

  final String apiBaseUrl =
      "https://projectstreaming-production.up.railway.app/api/movies";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse(apiBaseUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            movies = data.map((m) => Movie.fromJson(m)).toList();
            isLoading = false;
          });
        }
      } else {
        throw Exception("Error del servidor (${response.statusCode})");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "No se pudieron cargar los datos.";
        });
      }
    }
  }

  void _navigateToDetails(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MovieDetailsScreen(movie: movie, user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }

    if (errorMessage != null && movies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white24, size: 60),
            const SizedBox(height: 16),
            Text(errorMessage!, style: const TextStyle(color: Colors.white70)),
            TextButton(
              onPressed: () => _loadData(),
              child: const Text(
                "Reintentar",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(),
      color: Colors.red,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildStaticBanner(),
            _buildSection("Tendencias ahora", movies),
            _buildSection("Aclamadas por la crítica", movies.reversed.toList()),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticBanner() {
    if (movies.isEmpty) return const SizedBox.shrink();
    final mainMovie = movies[0];

    return GestureDetector(
      onTap: () => _navigateToDetails(mainMovie),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              mainMovie.backdropUrl ?? mainMovie.imageUrl ?? '',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Color(0xFF141414)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                mainMovie.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 50),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bannerButton(
                    Icons.play_arrow,
                    "Reproducir",
                    Colors.white,
                    Colors.black,
                    mainMovie,
                  ),
                  const SizedBox(width: 10),
                  _bannerButton(
                    Icons.info_outline,
                    "Información",
                    Colors.white24,
                    Colors.white,
                    mainMovie,
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bannerButton(
    IconData icon,
    String label,
    Color bg,
    Color txt,
    Movie movie,
  ) {
    return ElevatedButton.icon(
      onPressed: () => _navigateToDetails(movie),
      icon: Icon(icon, color: txt),
      label: Text(
        label,
        style: TextStyle(color: txt, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        minimumSize: const Size(140, 45),
      ),
    );
  }

  Widget _buildSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 20, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _navigateToDetails(list[i]),
              child: Container(
                width: 110,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  image: DecorationImage(
                    image: NetworkImage(list[i].imageUrl ?? ''),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
