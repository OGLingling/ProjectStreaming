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
  List<Movie> series = [];
  List<Movie> topRatedMovies = [];
  bool isLoading = true;

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _carouselTimer;

  final String apiBaseUrl =
      "https://projectstreaming-production-5629.up.railway.app/api/movies";

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

            movies = allContent.where((m) => m.type == 'movie').toList();
            series = allContent.where((m) => m.type == 'tv').toList();

            // Lógica de respaldo por si la API no devuelve tipos claros
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
      debugPrint("Error al cargar datos: $e");
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
    final bool isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildAutoCarousel(size, isMobile),
                SizedBox(height: isMobile ? 15 : 30),
                _buildSection("Películas para ti", movies, isMobile),
                SizedBox(height: isMobile ? 15 : 30),
                _buildSection("Series Populares", series, isMobile),
                const SizedBox(height: 100),
              ],
            ),
    );
  }

  Widget _buildAutoCarousel(Size size, bool isMobile) {
    if (topRatedMovies.isEmpty) return const SizedBox.shrink();

    // Altura ajustada para no dominar todo el scroll en móvil
    final carouselHeight = isMobile ? size.height * 0.65 : size.height * 0.80;

    return SizedBox(
      height: carouselHeight,
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
                  // En móvil usamos el póster vertical para mejor impacto visual
                  Image.network(
                    isMobile
                        ? (movie.imageUrl ?? '')
                        : (movie.backdropUrl ?? ''),
                    fit: BoxFit.cover,
                  ),

                  // Gradiente dinámico
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                          const Color(0xFF141414),
                        ],
                        stops: const [0.0, 0.4, 0.8, 1.0],
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: isMobile ? 40 : 60,
                    left: 20,
                    right: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          movie.title.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.bebasNeue(
                            color: Colors.white,
                            fontSize: isMobile ? 45 : 80,
                            letterSpacing: 2,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.stars,
                              color: Colors.blueAccent,
                              size: isMobile ? 16 : 22,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${movie.rating} | Destacado",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 13 : 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isMobile ? 20 : 30),

                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _netflixButton(
                              Icons.play_arrow,
                              "Ver ahora",
                              Colors.white,
                              Colors.black,
                              movie,
                              isMobile,
                            ),
                            _netflixButton(
                              Icons.info_outline,
                              "Detalles",
                              Colors.white.withOpacity(0.2),
                              Colors.white,
                              movie,
                              isMobile,
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

          // Paginación (Dots)
          Positioned(
            bottom: 15,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                topRatedMovies.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 4,
                  width: _currentPage == index ? 22 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.red
                        : Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
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
    bool isMobile,
  ) {
    return SizedBox(
      height: isMobile ? 42 : 50,
      child: ElevatedButton.icon(
        onPressed: () => _navigateToDetails(movie),
        icon: Icon(icon, color: textCol, size: isMobile ? 20 : 26),
        label: Text(
          text,
          style: TextStyle(
            color: textCol,
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: textCol,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Movie> list, bool isMobile) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 15 : 40,
            vertical: 10,
          ),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: isMobile ? 190 : 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 15 : 40),
            itemCount: list.length,
            itemBuilder: (context, i) => MovieCard(
              movie: list[i],
              onDetail: () => _navigateToDetails(list[i]),
              isMobile: isMobile,
            ),
          ),
        ),
      ],
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

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}

class MovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback onDetail;
  final bool isMobile;
  const MovieCard({
    super.key,
    required this.movie,
    required this.onDetail,
    required this.isMobile,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final double width = widget.isMobile ? 125 : 160;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onDetail,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 12),
          width: width,
          transform: (isHovered && !widget.isMobile)
              ? (Matrix4.identity()..scale(1.08))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Image.network(
                widget.movie.imageUrl ?? '',
                fit: BoxFit.cover,
                // Placeholder mientras carga la imagen
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.white10,
                    child: const Center(
                      child: Icon(Icons.movie, color: Colors.white24),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
