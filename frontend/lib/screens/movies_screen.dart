import 'dart:async';
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
  List<Movie> topRatedMovies = [];
  bool isLoading = true;

  // Controles para el carrusel
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _carouselTimer;

  final String apiBaseUrl =
      "https://projectstreaming-production.up.railway.app/api/movies";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final response = await http.get(Uri.parse(apiBaseUrl));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            movies = data.map((m) => Movie.fromJson(m)).toList();

            // Filtramos o sorteamos por rating para el carrusel (Top 5)
            topRatedMovies = List.from(movies);
            topRatedMovies.sort(
              (a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0),
            );
            topRatedMovies = topRatedMovies.take(5).toList();

            isLoading = false;
          });
          _startCarouselTimer();
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (topRatedMovies.isNotEmpty) {
        if (_currentPage < topRatedMovies.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildAutoCarousel(size),
                const SizedBox(height: 20),
                _buildSection("Tendencias ahora", movies),
                _buildSection(
                  "Aclamadas por la crítica",
                  movies.reversed.toList(),
                ),
                const SizedBox(height: 100),
              ],
            ),
    );
  }

  Widget _buildAutoCarousel(Size size) {
    if (topRatedMovies.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: size.height * 0.7,
      child: Stack(
        children: [
          // 1. EL CARRUSEL
          PageView.builder(
            controller: _pageController,
            itemCount: topRatedMovies.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final movie = topRatedMovies[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Imagen de fondo
                  Image.network(
                    movie.backdropUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) =>
                        Container(color: Colors.grey[900]),
                  ),
                  // Gradiente Negro
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xFF141414),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  // Información de la película
                  Positioned(
                    bottom: 60,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Text(
                          movie.title.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.bebasNeue(
                            color: Colors.white,
                            fontSize: 55,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "${movie.rating ?? 0.0} | Destacada",
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _netflixButton(
                              Icons.play_arrow,
                              "Reproducir",
                              Colors.white,
                              Colors.black,
                              movie,
                            ),
                            const SizedBox(width: 15),
                            _netflixButton(
                              Icons.info_outline,
                              "Información",
                              Colors.grey.withOpacity(0.5),
                              Colors.white,
                              movie,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // 2. INDICADORES (Puntitos)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                topRatedMovies.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 20 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? Colors.red : Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _netflixButton(
    IconData icon,
    String text,
    Color bg,
    Color textCol,
    Movie movie,
  ) {
    return ElevatedButton.icon(
      onPressed: () => _navigateToDetails(movie),
      icon: Icon(icon, color: textCol, size: 26),
      label: Text(
        text,
        style: TextStyle(
          color: textCol,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  void _navigateToDetails(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => MovieDetailsScreen(movie: movie, user: widget.user),
      ),
    );
  }

  Widget _buildSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            padding: const EdgeInsets.only(left: 16),
            itemCount: list.length,
            itemBuilder: (context, i) => MovieCard(
              movie: list[i],
              onDetail: () => _navigateToDetails(list[i]),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}

// --- MovieCard permanece igual que tu código original ---
class MovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback onDetail;
  const MovieCard({super.key, required this.movie, required this.onDetail});

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onDetail,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 12),
          width: isHovered ? 130 : 110,
          curve: Curves.easeInOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              widget.movie.imageUrl ?? '',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
