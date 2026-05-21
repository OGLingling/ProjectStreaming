import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movie_model.dart';
import '../services/api_service.dart';
import 'movie_details_screen.dart';
import 'video_player_screen.dart';

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
  List<Map<String, dynamic>> continueWatching = [];
  bool isLoading = true;

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _carouselTimer;

  final String apiBaseUrl =
      "https://projectstreaming-1.onrender.com/api/movies";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = widget.user?['id']?.toString();
      final response = await http.get(Uri.parse(apiBaseUrl));
      final progressFuture = userId == null || userId.isEmpty
          ? Future<List<dynamic>>.value([])
          : ApiService.getViewingProgress(userId);
      if (response.statusCode == 200) {
        final progressData = await progressFuture;
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
            topRatedMovies.sort((a, b) => b.rating.compareTo(a.rating));
            topRatedMovies = topRatedMovies.take(5).toList();
            continueWatching = progressData
                .whereType<Map<String, dynamic>>()
                .toList();

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: colorScheme.secondary),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildAutoCarousel(size, isMobile),
                SizedBox(height: isMobile ? 15 : 30),
                _buildContinueWatchingSection(isMobile),
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
    final colorScheme = Theme.of(context).colorScheme;

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
                          Colors.black.withValues(alpha: 0.2),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                          colorScheme.surface,
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
                              color: colorScheme.secondary,
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
                              colorScheme.primary,
                              colorScheme.onPrimary,
                              movie,
                              isMobile,
                            ),
                            _netflixButton(
                              Icons.info_outline,
                              "Detalles",
                              colorScheme.surfaceContainerHighest.withValues(
                                alpha: 0.82,
                              ),
                              colorScheme.onSurface,
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
                        ? colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.5),
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
    final colorScheme = Theme.of(context).colorScheme;
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
              color: colorScheme.onSurface,
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

  Widget _buildContinueWatchingSection(bool isMobile) {
    if (continueWatching.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 15 : 40,
            vertical: 10,
          ),
          child: Text(
            "Continuar viendo",
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: isMobile ? 225 : 295,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 15 : 40),
            itemCount: continueWatching.length,
            itemBuilder: (context, index) {
              final item = continueWatching[index];
              return ContinueWatchingCard(
                item: item,
                isMobile: isMobile,
                onTap: () => _continuePlayback(item),
                onDetails: () => _openProgressDetails(item),
              );
            },
          ),
        ),
      ],
    );
  }

  void _continuePlayback(Map<String, dynamic> item) {
    final userId = widget.user?['id']?.toString();
    final tmdbId = (item['tmdb_id'] ?? item['tmdbId'])?.toString();
    if (userId == null || tmdbId == null || tmdbId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          userId: userId,
          contentId: int.tryParse(
            (item['contentId'] ?? item['id'])?.toString() ?? '',
          ),
          tmdbId: tmdbId,
          title: item['title']?.toString() ?? 'Contenido',
          type: item['type']?.toString() ?? 'movie',
          season: int.tryParse(item['seasonNumber']?.toString() ?? '') ?? 1,
          episode: int.tryParse(item['episodeNumber']?.toString() ?? '') ?? 1,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _openProgressDetails(Map<String, dynamic> item) {
    final movie = Movie.fromJson({
      ...item,
      'id': item['contentId'] ?? item['id'],
      'tmdbId': item['tmdbId'] ?? item['tmdb_id'],
      'tmdb_id': item['tmdb_id'] ?? item['tmdbId'],
      'releaseDate': item['releaseDate'] ?? 'Sin fecha de estreno',
      'rating': item['rating'] ?? 0.0,
    });
    _navigateToDetails(movie);
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

class ContinueWatchingCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isMobile;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  const ContinueWatchingCard({
    super.key,
    required this.item,
    required this.isMobile,
    required this.onTap,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = isMobile ? 155.0 : 210.0;
    final image =
        (item['imageUrl'] ?? item['image'] ?? item['backdropUrl'] ?? '')
            .toString();
    final progress = double.tryParse(item['progress']?.toString() ?? '') ?? 0.0;
    final type = item['type']?.toString().toLowerCase() ?? 'movie';
    final isTv = type.contains('tv') || type.contains('serie');
    final season = item['seasonNumber']?.toString() ?? '1';
    final episode = item['episodeNumber']?.toString() ?? '1';

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.movie_creation_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            colorScheme.surface.withValues(alpha: 0.82),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: colorScheme.onPrimary,
                          size: 28,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 4,
                        color: colorScheme.primary,
                        backgroundColor: colorScheme.onSurface.withValues(
                          alpha: 0.18,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: IconButton(
                        onPressed: onDetails,
                        icon: const Icon(Icons.info_outline, size: 18),
                        color: colorScheme.onSurface,
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surface.withValues(
                            alpha: 0.74,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item['title']?.toString() ?? 'Contenido',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: isMobile ? 13 : 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isTv ? 'T$season:E$episode' : 'Película',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
              ? (Matrix4.identity()..scaleByDouble(1.08, 1.08, 1.0, 1.0))
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
