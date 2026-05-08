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
      // ✅ CORRECCIÓN: Uso estático de ApiService
      final List<dynamic> data = await ApiService.getMoviesByType('tv');

      if (mounted) {
        setState(() {
          seriesList = data
              .map((m) => Movie.fromJson(m))
              .where((m) => m.type.toLowerCase() == 'tv')
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
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: topRatedSeries.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => _buildCarouselItem(topRatedSeries[index]),
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
                style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 50, letterSpacing: 2),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 5),
                  Text(
                    "${series.rating ?? 0.0} | Top Serie",
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
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
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
    Navigator.push(context, MaterialPageRoute(builder: (c) => MovieDetailsScreen(movie: series)));
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}