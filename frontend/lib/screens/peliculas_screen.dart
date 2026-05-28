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
      // ✅ Uso correcto del método estático
      final List<dynamic> data = await ApiService.getMoviesByType('movie');

      if (mounted) {
        setState(() {
          moviesList = data
              .map((m) => Movie.fromJson(m))
              .where((m) => m.type.toLowerCase() == 'movie')
              .toList();

          topRatedMovies = moviesList
              .where((m) => (m.backdropUrl ?? m.imageUrl ?? '').isNotEmpty)
              .toList();
          topRatedMovies.sort((a, b) => b.rating.compareTo(a.rating));
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

  void _navigateToDetails(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => MovieDetailsScreen(movie: movie)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: colorScheme.secondary),
            )
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
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: size.height * 0.7,
      child: PageView.builder(
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black45,
                      Colors.transparent,
                      colorScheme.surface,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
              Positioned(
                bottom: 60,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    Text(
                      movie.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 45,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star,
                          color: colorScheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "${movie.rating} | Tendencia",
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }

  Widget _buildTitleSection(String title) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, top: 30, bottom: 15),
        child: Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
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

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}

// ─── COMPONENTES REQUERIDOS PARA LA COMPILACIÓN ──────────────────────────────

class _HoverButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _HoverButton({
    required this.text,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: isPrimary
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPrimary
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                size: 26,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: isPrimary
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoviePosterCard extends StatelessWidget {
  final Movie movie;

  const _MoviePosterCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => MovieDetailsScreen(movie: movie)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              movie.imageUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                color: Colors.grey[900],
                child: const Icon(Icons.movie, color: Colors.white24),
              ),
            ),
            // Sombra inferior para legibilidad del título si decides mostrarlo
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
