import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/movie_model.dart';
import 'movie_details_screen.dart';
import 'watchlist_providers.dart';

class MyListScreen extends StatelessWidget {
  final String userId;
  final Map<String, dynamic>? user;

  const MyListScreen({super.key, required this.userId, this.user});

  // Función para obtener la data completa desde la API de TMDB
  Future<Movie?> _fetchFullMovieData(dynamic rawId, String? rawType) async {
    const String apiKey = 'd8a00b94f5c00821e497b569fec9a61f';

    // 1. Limpieza y validación del ID
    final String idString = rawId?.toString() ?? '';
    if (idString.isEmpty || idString == 'null') return null;

    // 2. Normalización de Tipo (movie o tv)
    String type = 'movie';
    if (rawType != null) {
      String t = rawType.toLowerCase();
      if (t == 'tv' || t == 'serie' || t == 'series') type = 'tv';
    }

    final url = Uri.parse(
      'https://api.themoviedb.org/3/$type/$idString?api_key=$apiKey&language=es-ES&append_to_response=videos,credits,images,seasons',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Mapeo manual para asegurar que MovieDetailsScreen tenga todo para reproducir
        return Movie(
          id: data['id'] ?? 0,
          tmdbId: data['id']?.toString() ?? idString,
          title: data['title'] ?? data['name'] ?? 'Sin título',
          description: data['overview'] ?? 'Sin sinopsis disponible',
          releaseDate: data['release_date'] ?? data['first_air_date'] ?? '',
          imageUrl: data['poster_path'] ?? '',
          backdropUrl: data['backdrop_path'] ?? '',
          rating: (data['vote_average'] as num?)?.toDouble() ?? 0.0,
          category: '',
          type: type,
          seasons: data['seasons'] ?? [],
        );
      }
    } catch (e) {
      debugPrint("Error al consultar TMDB: $e");
    }
    return null;
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
                // Diseño de posters pequeños (7 en web, 3 en móvil)
                int crossAxisCount = constraints.maxWidth > 1200 ? 7 : 3;

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

                    // PRIORIDAD DE ID: Intentamos tmdb_id primero, luego contentId
                    final dynamic tmdbId =
                        item['tmdb_id'] ?? item['tmdbId'] ?? item['contentId'];
                    final String type = item['type'] ?? 'tv';

                    return InkWell(
                      onTap: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(color: Colors.red),
                          ),
                        );

                        final movie = await _fetchFullMovieData(tmdbId, type);

                        if (context.mounted) {
                          Navigator.pop(context); // Cierra el loading
                          if (movie != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MovieDetailsScreen(
                                  movie: movie,
                                  user: user,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Error: El ID de la serie no es válido",
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              item['image']?.toString().startsWith('http') ==
                                      true
                                  ? item['image']
                                  : 'https://image.tmdb.org/t/p/w500${item['image']}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey[900],
                                    child: const Icon(
                                      Icons.movie,
                                      color: Colors.white24,
                                    ),
                                  ),
                            ),
                            // Botón para eliminar
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => provider.toggleWatchlist(
                                  userId,
                                  int.tryParse(tmdbId.toString()) ?? 0,
                                  item['title'] ?? '',
                                  item['image'] ?? '',
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
                );
              },
            ),
    );
  }
}
