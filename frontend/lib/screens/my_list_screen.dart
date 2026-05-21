import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/movie_model.dart';
import 'movie_details_screen.dart';
import 'watchlist_providers.dart';

class MyListScreen extends StatelessWidget {
  final String userId;
  final Map<String, dynamic>? user;

  const MyListScreen({super.key, required this.userId, this.user});

  String? _readTmdbId(Map<String, dynamic> item) {
    final raw = item['tmdb_id'] ?? item['tmdbId'] ?? item['tmdbID'];
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }
    return value;
  }

  int _readContentId(Map<String, dynamic> item) {
    final raw = item['id'] ?? item['contentId'] ?? item['content_id'];
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _readType(Map<String, dynamic> item) {
    final type = (item['type'] ?? 'movie').toString().toLowerCase();
    return type.contains('tv') || type.contains('serie') ? 'tv' : 'movie';
  }

  String _readTitle(Map<String, dynamic> item) {
    final title = item['title']?.toString().trim();
    return title == null || title.isEmpty ? 'Contenido' : title;
  }

  String _readImage(Map<String, dynamic> item) {
    final raw = (item['image'] ?? item['imageUrl'] ?? item['posterPath'] ?? '')
        .toString()
        .trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('/')) return 'https://image.tmdb.org/t/p/w500$raw';
    return raw;
  }

  void _openDetails(BuildContext context, Map<String, dynamic> item) {
    final tmdbId = _readTmdbId(item);
    if (tmdbId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se encontró el ID de TMDB.")),
      );
      return;
    }

    final movie = Movie.fromJson({
      ...item,
      'id': _readContentId(item),
      'tmdbId': tmdbId,
      'tmdb_id': tmdbId,
      'title': _readTitle(item),
      'type': _readType(item),
      'imageUrl': _readImage(item),
      'releaseDate': item['releaseDate'] ?? 'Sin fecha de estreno',
      'rating': item['rating'] ?? 0.0,
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movie: movie, user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WatchlistProvider>(context);
    final watchlist = provider.watchlist;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        title: Text(
          "Mi lista",
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: provider.isLoading
          ? Center(
              child: CircularProgressIndicator(color: colorScheme.secondary),
            )
          : watchlist.isEmpty
          ? Center(
              child: Text(
                "Tu lista está vacía",
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1200 ? 7 : 3;

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.67,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: watchlist.length,
                  itemBuilder: (context, index) {
                    final item = watchlist[index];
                    final contentId = _readContentId(item);
                    final title = _readTitle(item);
                    final image = _readImage(item);
                    final tmdbId = _readTmdbId(item);
                    final type = _readType(item);

                    return InkWell(
                      onTap: () => _openDetails(context, item),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (image.isNotEmpty)
                              Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPosterFallback(),
                              )
                            else
                              _buildPosterFallback(),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  if (contentId == 0) return;
                                  provider.toggleWatchlist(
                                    userId,
                                    contentId,
                                    title,
                                    image,
                                    tmdbId: tmdbId,
                                    type: type,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface.withValues(
                                      alpha: 0.86,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: colorScheme.onSurface,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildPosterFallback() {
    return Container(
      color: Colors.grey[900],
      child: const Icon(Icons.movie, color: Colors.white24),
    );
  }
}
