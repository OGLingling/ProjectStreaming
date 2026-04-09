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
  List<Movie> series = []; // Lista separada para series
  List<Movie> topRatedMovies = [];
  bool isLoading = true;

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
            final allContent = data.map((m) => Movie.fromJson(m)).toList();

            // Filtramos series y películas (ajusta según tu modelo de datos)
            movies = allContent.where((m) => m.type == 'movie').toList();
            series = allContent.where((m) => m.type == 'tv').toList();

            // Si no tienes el campo 'type', simplemente divide la lista para pruebas:
            if (series.isEmpty && allContent.length > 5) {
              series = allContent.sublist(allContent.length ~/ 2);
            }

            topRatedMovies = List.from(allContent);
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
                const SizedBox(height: 30),
                _buildSection("Películas para ti", movies),
                const SizedBox(height: 30),
                // Nueva sección de Series con el mismo comportamiento
                _buildSection("Series Populares", series),
                const SizedBox(height: 100),
              ],
            ),
    );
  }

  // --- El carrusel automático se mantiene igual ---
  Widget _buildAutoCarousel(Size size) {
    if (topRatedMovies.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size.height * 0.75,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: topRatedMovies.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final movie = topRatedMovies[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(movie.backdropUrl ?? '', fit: BoxFit.cover),
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
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    left: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie.title.toUpperCase(),
                          style: GoogleFonts.bebasNeue(
                            color: Colors.white,
                            fontSize: 65,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
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
                              "Más info",
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
      icon: Icon(icon, color: textCol, size: 28),
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
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
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
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 250, // Un poco más alto para permitir el escalado (pop-up)
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 40),
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

// --- MovieCard con EFECTO POP-UP ---
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(right: 15),
          width: 150,
          // El secreto del Pop-Up está en el Transform.scale:
          // Escala la tarjeta sin empujar a las vecinas
          transform: isHovered
              ? (Matrix4.identity()..scale(1.2))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isHovered
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ]
                        : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.movie.imageUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              if (isHovered)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    widget.movie.title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
