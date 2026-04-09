import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../models/movie_model.dart';
import 'movie_details_screen.dart';

class SeriesScreen extends StatefulWidget {
  final bool isActive;
  const SeriesScreen({super.key, this.isActive = false});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<Movie> seriesList = [];
  List<Movie> topRatedSeries = [];
  bool isLoading = true;

  // Controles para el carrusel superior (Top 5)
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    try {
      // Obtenemos los datos desde el servicio
      final List<dynamic> data = await ApiService.getMoviesByType('tv');

      if (mounted) {
        setState(() {
          // 1. Mapeamos y validamos que el tipo sea 'Serie'
          seriesList = data
              .map((m) => Movie.fromJson(m))
              .where((m) => m.type.toLowerCase() == 'tv')
              .toList();

          // 2. Filtramos las 5 series con mejor rating para el banner
          topRatedSeries = List.from(seriesList);
          topRatedSeries.sort(
            (a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0),
          );
          topRatedSeries = topRatedSeries.take(5).toList();

          isLoading = false;
        });
        _startCarouselTimer();
      }
    } catch (e) {
      debugPrint("Error al cargar series: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (topRatedSeries.isNotEmpty && _pageController.hasClients) {
        _currentPage = (_currentPage + 1) % topRatedSeries.length;
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
                // 1. BANNER DINÁMICO (CARRUSEL DE SERIES TOP)
                SliverToBoxAdapter(child: _buildSeriesCarousel()),

                // 2. TÍTULO DE SECCIÓN
                _buildTitleSection("Series Populares"),

                // 3. GRID DE SERIES (CATÁLOGO COMPLETO)
                _buildSeriesGrid(),

                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
            ),
    );
  }

  Widget _buildSeriesCarousel() {
    final size = MediaQuery.of(context).size;
    if (topRatedSeries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: size.height * 0.7,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: topRatedSeries.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final series = topRatedSeries[index];
              return _buildCarouselItem(series);
            },
          ),
          // Indicadores inferiores (Dots)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                topRatedSeries.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 22 : 8,
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

  Widget _buildCarouselItem(Movie series) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          series.backdropUrl ?? series.imageUrl ?? '',
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(color: Colors.black),
        ),
        // Gradiente oscuro
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black26, Colors.transparent, Color(0xFF141414)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Información de la Serie
        Positioned(
          bottom: 70,
          left: 20,
          right: 20,
          child: Column(
            children: [
              Text(
                series.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.bebasNeue(
                  color: Colors.white,
                  fontSize: 60,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 5),
                  Text(
                    "${series.rating} | Top Serie de la Semana",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _HoverButton(
                    text: "Ver ahora",
                    icon: Icons.play_arrow,
                    isPrimary: true,
                    onTap: () => _navigateToDetails(series),
                  ),
                  const SizedBox(width: 15),
                  _HoverButton(
                    text: "Más detalles",
                    icon: Icons.info_outline,
                    isPrimary: false,
                    onTap: () => _navigateToDetails(series),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, top: 30, bottom: 15),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSeriesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 18,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _SeriesPosterCard(series: seriesList[index]),
          childCount: seriesList.length,
        ),
      ),
    );
  }

  void _navigateToDetails(Movie series) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => MovieDetailsScreen(movie: series)),
    );
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}

// --- WIDGET PARA LOS BOTONES (Igual que en Peliculas) ---
class _HoverButton extends StatefulWidget {
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
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isPrimary
                  ? (_isHovered ? Colors.white.withOpacity(0.9) : Colors.white)
                  : (_isHovered
                        ? Colors.grey.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: widget.isPrimary ? Colors.black : Colors.white,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.text,
                  style: TextStyle(
                    color: widget.isPrimary ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- WIDGET PARA LAS TARJETAS (Efecto Escala y Sombra) ---
class _SeriesPosterCard extends StatefulWidget {
  final Movie series;
  const _SeriesPosterCard({required this.series});

  @override
  State<_SeriesPosterCard> createState() => _SeriesPosterCardState();
}

class _SeriesPosterCardState extends State<_SeriesPosterCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailsScreen(movie: widget.series),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.1))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.7),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  widget.series.imageUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(color: Colors.grey[900]),
                ),
                if (_isHovered)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 45,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
