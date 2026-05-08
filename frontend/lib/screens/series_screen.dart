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
      // ✅ Uso del método estático corregido
      final List<dynamic> data = await ApiService.getMoviesByType('tv');

      if (mounted) {
        setState(() {
          // Filtrado defensivo: evitamos nulos y verificamos el tipo 'tv'
          seriesList = data
              .map((m) => Movie.fromJson(m))
              .where((m) => m.type.toLowerCase() == 'tv' || m.type.toLowerCase() == 'serie')
              .toList();

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

  void _navigateToDetails(Movie series) {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (c) => MovieDetailsScreen(movie: series))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildSeriesCarousel()),
                _buildTitleSection("Series Populares"),
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
      child: PageView.builder(
        controller: _pageController,
        itemCount: topRatedSeries.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) => _buildCarouselItem(topRatedSeries[index]),
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
        Positioned(
          bottom: 70, left: 20, right: 20,
          child: Column(
            children: [
              Text(
                series.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.bebasNeue(
                  color: Colors.white, 
                  fontSize: 50, 
                  letterSpacing: 2
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 5),
                  Text(
                    "${series.rating ?? 0.0} | Top Serie",
                    style: const TextStyle(
                      color: Colors.white70, 
                      fontWeight: FontWeight.w600
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
            fontSize: 22, 
            fontWeight: FontWeight.bold
          )
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
          childAspectRatio: 0.65,
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

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}

// ─── WIDGETS DE APOYO (REQUERIDOS PARA COMPILAR) ─────────────────────────────

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isPrimary ? Colors.black : Colors.white),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: isPrimary ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesPosterCard extends StatelessWidget {
  final Movie series;

  const _SeriesPosterCard({required this.series});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => MovieDetailsScreen(movie: series)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              series.imageUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                color: Colors.grey[900],
                child: const Icon(Icons.movie, color: Colors.white24),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  series.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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