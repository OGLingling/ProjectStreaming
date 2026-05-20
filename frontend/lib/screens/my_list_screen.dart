import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'video_player_screen.dart';
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

  void _openPlayer(BuildContext context, Map<String, dynamic> item) {
    final tmdbId = _readTmdbId(item);
    if (tmdbId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se encontró el ID de TMDB.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          tmdbId: tmdbId,
          title: _readTitle(item),
          type: _readType(item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WatchlistProvider>(context);
    final watchlist = provider.watchlist;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Mi lista",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : watchlist.isEmpty
          ? const Center(
              child: Text(
                "Tu lista está vacía",
                style: TextStyle(color: Colors.white60),
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
                      onTap: () => _openPlayer(context, item),
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
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
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
