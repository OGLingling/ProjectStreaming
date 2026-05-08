import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../models/movie_model.dart';
import 'movie_details_screen.dart';

class PeliculasScreen extends StatefulWidget {
  final bool isActive;
  const PeliculasScreen({super.key, this.isActive = false});

  @override
  State<PeliculasScreen> createState() => _PeliculasScreenState();
}

class _PeliculasScreenState extends State<PeliculasScreen> {
  List<Movie> moviesList = [];
  List<Movie> topRatedMovies = [];
  bool isLoading = true;

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    try {
      // ✅ CORRECCIÓN: Llamada estática al servicio
      final List<dynamic> data = await ApiService.getMoviesByType('movie');

      if (mounted) {
        setState(() {
          moviesList = data
              .map((m) => Movie.fromJson(m))
              .where((m) => m.type.toLowerCase() == 'movie')
              .toList();

          topRatedMovies = List.from(moviesList);
          topRatedMovies.sort(
            (a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0),
          );
          topRatedMovies = topRatedMovies.take(5).toList();

          isLoading = false;
        });
        _startCarouselTimer();
      }
    } catch (e) {
      debugPrint("Error al cargar películas: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (topRatedMovies.isNotEmpty && _pageController.hasClients) {
        _currentPage = (_currentPage + 1) % topRatedMovies.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildDynamicBanner()),
                _buildTitleSection("Películas para ti"),
                _buildMovieGrid(),
                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
            ),
    );
  }

  Widget _buildDynamicBanner() {
    final size = MediaQuery.of(context).size;
    if (topRatedMovies.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: size.height * 0.7,
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
                  Image.network(
                    movie.backdropUrl ?? movie.imageUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(color: Colors.black),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.transparent, Color(0xFF141414)],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 60, left: 20, right: 20,
                    child: Column(
                      children: [
                        Text(
                          movie.title.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.bebasNeue(
                            color: Colors.white,
                            fontSize: 50, // Ajustado para evitar overflow
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 5),
                            Text(
                              "${movie.rating ?? 0.0} | Tendencia",
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _HoverButton(
                              text: "Reproducir",
                              icon: Icons.play_arrow,
                              isPrimary: true,
                              onTap: () => _navigateToDetails(movie),
                            ),
                            const SizedBox(width: 15),
                            _HoverButton(
                              text: "Información",
                              icon: Icons.info_outline,
                              isPrimary: false,
                              onTap: () => _navigateToDetails(movie),
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

  Widget _buildTitleSection(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, top: 30, bottom: 15),
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMovieGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.68,
          crossAxisSpacing: 15,
          mainAxisSpacing: 20,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _MoviePosterCard(movie: moviesList[index]),
          childCount: moviesList.length,
        ),
      ),
    );
  }

  void _navigateToDetails(Movie movie) {
    Navigator.push(context, MaterialPageRoute(builder: (c) => MovieDetailsScreen(movie: movie)));
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}