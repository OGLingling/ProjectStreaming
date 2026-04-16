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
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // Posters pequeños como en el inicio
                childAspectRatio: 0.68, // Proporción vertical correcta
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: watchlist.length,
              itemBuilder: (context, index) {
                final item = watchlist[index];

                // --- CONVERSIÓN SEGURA SEGÚN TU MODELO ---
                // 1. Extraemos el ID numérico
                final int? rawId = int.tryParse(item['id'].toString());

                final movie = Movie(
                  id: rawId, // Es int? según tu modelo
                  tmdbId: rawId?.toString(), // Es String? según tu modelo
                  title: item['title'] ?? '',
                  description: '', // Opcional
                  releaseDate: '2024',
                  imageUrl: item['image'] ?? '',
                  backdropUrl: item['image'] ?? '',
                  rating: 0.0,
                  type: item['type'] ?? 'tv', // 'tv' o 'movie'
                  seasons: [], // Lista vacía por defecto
                );

                return InkWell(
                  onTap: () {
                    // Navegación para visualizar y reproducir
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MovieDetailsScreen(movie: movie, user: user),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Poster
                        Image.network(
                          movie.imageUrl ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.grey[900]),
                        ),
                        // Botón de eliminar
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
            ),
    );
  }
}
