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
              // Ajustamos padding para que no se pegue a los bordes
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 columnas para posters pequeños
                childAspectRatio:
                    0.65, // FIX: Proporción vertical delgada (como tu foto de referencia)
                crossAxisSpacing: 10, // Espaciado horizontal entre posters
                mainAxisSpacing: 12, // Espaciado vertical entre filas
              ),
              itemCount: watchlist.length,
              itemBuilder: (context, index) {
                final item = watchlist[index];

                // --- CONVERSIÓN SEGURA DE DATOS ---
                final int? rawId = int.tryParse(item['id'].toString());
                final String imageUrl = item['image'] ?? '';

                final movie = Movie(
                  id: rawId,
                  tmdbId: rawId?.toString(),
                  title: item['title'] ?? '',
                  description: '',
                  releaseDate: '2024',
                  imageUrl: imageUrl, // URL de la imagen
                  backdropUrl: imageUrl,
                  rating: 0.0,
                  type: item['type'] ?? 'tv',
                  seasons: [],
                );

                return InkWell(
                  onTap: () {
                    // Navegación funcional para reproducir
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MovieDetailsScreen(movie: movie, user: user),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      4,
                    ), // Esquinas ligeramente redondeadas
                    child: Stack(
                      children: [
                        // --- FIX: VISUALIZACIÓN DE IMAGEN ---
                        // Usamos Positioned.fill para que la imagen ocupe todo el espacio del GridTile
                        Positioned.fill(
                          child: Image.network(
                            movie.imageUrl ?? '',
                            fit: BoxFit
                                .cover, // Importante para que la imagen se adapte sin deformarse
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[900],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.white24,
                                  ),
                                ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(color: Colors.grey[900]);
                            },
                          ),
                        ),
                        // Botón de eliminar (X) más pequeño y estético
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
                                color: Colors
                                    .black87, // Fondo más oscuro para contraste
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16, // Tamaño del icono reducido
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
