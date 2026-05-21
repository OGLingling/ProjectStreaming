import 'package:flutter/material.dart';

import '../models/movie_model.dart';
import '../services/api_service.dart';
import 'movie_details_screen.dart';
import 'video_player_screen.dart';

class NovedadesScreen extends StatefulWidget {
  final Map<String, dynamic>? user;

  const NovedadesScreen({super.key, this.user});

  @override
  State<NovedadesScreen> createState() => _NovedadesScreenState();
}

class _NovedadesScreenState extends State<NovedadesScreen> {
  List<Movie> _movies = [];
  List<Movie> _series = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNovedades();
  }

  Future<void> _loadNovedades() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        ApiService.getMoviesByType('movie'),
        ApiService.getMoviesByType('tv'),
      ]);

      final movies = responses[0].map((item) => Movie.fromJson(item)).toList();
      final series = responses[1].map((item) => Movie.fromJson(item)).toList();

      movies.sort(_sortByReleaseDateDesc);
      series.sort(_sortByReleaseDateDesc);

      if (!mounted) return;
      setState(() {
        _movies = movies;
        _series = series;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las novedades.';
        _isLoading = false;
      });
    }
  }

  int _sortByReleaseDateDesc(Movie a, Movie b) {
    final dateA = DateTime.tryParse(a.releaseDate);
    final dateB = DateTime.tryParse(b.releaseDate);

    if (dateA != null && dateB != null) return dateB.compareTo(dateA);
    if (dateA != null) return -1;
    if (dateB != null) return 1;
    return b.rating.compareTo(a.rating);
  }

  Map<String, int>? _firstPlayableEpisode(Movie movie) {
    final seasons = movie.seasons ?? [];

    for (final season in seasons) {
      final episodes = season.episodes ?? [];
      if (season.seasonNumber > 0 && episodes.isNotEmpty) {
        return {
          'season': season.seasonNumber,
          'episode': episodes.first.episodeNumber,
        };
      }
    }

    return null;
  }

  void _openDetails(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MovieDetailsScreen(movie: movie, user: widget.user),
      ),
    );
  }

  void _play(Movie movie) {
    final tmdbId = movie.tmdbId?.trim();
    if (tmdbId == null || tmdbId.isEmpty) {
      _showSnackBar('ID de TMDB no disponible para reproducir.');
      return;
    }

    int season = 1;
    int episode = 1;

    if (_isTv(movie)) {
      final firstEpisode = _firstPlayableEpisode(movie);
      if (firstEpisode == null) {
        _showSnackBar('No hay episodios disponibles para esta serie.');
        return;
      }

      season = firstEpisode['season']!;
      episode = firstEpisode['episode']!;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          tmdbId: tmdbId,
          contentId: movie.id,
          userId: widget.user?['id']?.toString(),
          title: movie.title,
          type: movie.type,
          season: season,
          episode: episode,
        ),
      ),
    );
  }

  bool _isTv(Movie movie) {
    final type = movie.type.toLowerCase();
    return type.contains('tv') || type.contains('serie');
  }

  void _showSnackBar(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allRecent = [..._movies, ..._series]..sort(_sortByReleaseDateDesc);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: colorScheme.secondary,
          backgroundColor: colorScheme.surface,
          onRefresh: _loadNovedades,
          child: _buildBody(allRecent.take(10).toList()),
        ),
      ),
    );
  }

  Widget _buildBody(List<Movie> recent) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.secondary),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          Icon(
            Icons.cloud_off_outlined,
            color: colorScheme.secondary,
            size: 42,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton.icon(
              onPressed: _loadNovedades,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (recent.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          Icon(
            Icons.auto_awesome_motion_outlined,
            color: colorScheme.secondary,
            size: 44,
          ),
          const SizedBox(height: 16),
          Text(
            'Aun no hay novedades disponibles.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(recent.first)),
        _buildSection('Recién agregados', recent),
        _buildSection('Nuevas películas', _movies.take(12).toList()),
        _buildSection('Nuevas series', _series.take(12).toList()),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  Widget _buildHeader(Movie featured) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final height = size.height * 0.44;
    final image = featured.backdropUrl ?? featured.imageUrl ?? '';

    return SizedBox(
      height: height.clamp(320.0, 460.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _PosterFallback(
              iconSize: 58,
              color: colorScheme.surfaceContainerHighest,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface.withValues(alpha: 0.16),
                  colorScheme.surface.withValues(alpha: 0.54),
                  colorScheme.surface,
                ],
                stops: const [0.0, 0.62, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Novedades',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  featured.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _metadata(featured),
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.play_arrow,
                        label: 'Reproducir',
                        isPrimary: true,
                        onTap: () => _play(featured),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.info_outline,
                        label: 'Detalles',
                        isPrimary: false,
                        onTap: () => _openDetails(featured),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Movie> items) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final cardWidth = isMobile ? 142.0 : 174.0;
    final cardHeight = isMobile ? 260.0 : 312.0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: isMobile ? 21 : 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _NovedadCard(
                  movie: items[index],
                  width: cardWidth,
                  onPlay: () => _play(items[index]),
                  onDetails: () => _openDetails(items[index]),
                  metadata: _metadata(items[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _metadata(Movie movie) {
    final year = movie.releaseDate.length >= 4
        ? movie.releaseDate.substring(0, 4)
        : 'Sin fecha';
    final type = _isTv(movie) ? 'Serie' : 'Película';
    final rating = movie.rating > 0 ? movie.rating.toStringAsFixed(1) : 'N/R';
    return '$type · $year · $rating';
  }
}

class _NovedadCard extends StatelessWidget {
  final Movie movie;
  final double width;
  final VoidCallback onPlay;
  final VoidCallback onDetails;
  final String metadata;

  const _NovedadCard({
    required this.movie,
    required this.width,
    required this.onPlay,
    required this.onDetails,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final image = movie.imageUrl ?? movie.backdropUrl ?? '';

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: onDetails,
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _PosterFallback(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Material(
                        color: colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onPlay,
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Icon(
                              Icons.play_arrow,
                              color: colorScheme.onPrimary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metadata,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.86),
        foregroundColor: isPrimary
            ? colorScheme.onPrimary
            : colorScheme.onSurface,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  final Color color;
  final double iconSize;

  const _PosterFallback({required this.color, this.iconSize = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.32),
          size: iconSize,
        ),
      ),
    );
  }
}
