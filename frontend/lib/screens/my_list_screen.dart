import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/movie_model.dart';
import 'movie_details_screen.dart';
import 'watchlist_providers.dart';

class MyListScreen extends StatelessWidget {
  final String userId;
  final Map<String, dynamic>? user;

  const MyListScreen({super.key, required this.userId, this.user});

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
                "Aún no tienes nada en tu lista",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // Calculamos columnas según el ancho para que siempre sean pequeños
                // En Web (ancho > 1200) pondrá 7 columnas, en móvil 3.
                int crossAxisCount = constraints.maxWidth > 1200
                    ? 7
                    : constraints.maxWidth > 800
                    ? 5
                    : 3;

                return GridView.builder(
                  padding: const EdgeInsets.all(15),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio:
                        0.67, // Proporción vertical exacta de poster
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: watchlist.length,
                  itemBuilder: (context, index) {
                    final item = watchlist[index];
                    final int? rawId = int.tryParse(item['id'].toString());
                    final String imageUrl = item['image'] ?? '';

                    final movie = Movie(
                      id: rawId,
                      tmdbId: rawId?.toString(),
                      title: item['title'] ?? '',
                      releaseDate: '2024',
                      imageUrl: imageUrl,
                      backdropUrl: imageUrl,
                      rating: 0.0,
                      type: item['type'] ?? 'tv',
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MovieDetailsScreen(
                                  movie: movie,
                                  user: user,
                                ),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.network(
                                      movie.imageUrl ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: Colors.grey[900],
                                              ),
                                    ),
                                  ),
                                  // Botón X pequeño
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => provider.toggleWatchlist(
                                        userId,
                                        movie.id ?? 0,
                                        movie.title,
                                        movie.imageUrl ?? '',
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}
