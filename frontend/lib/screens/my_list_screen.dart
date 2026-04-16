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
  Future<Movie?> _fetchFullMovieData(dynamic rawTmdbId, String? rawType) async {
    const String apiKey = 'd8a00b94f5c00821e497b569fec9a61f';

    // 1. Validación y limpieza del ID de TMDB
    final String tmdbId = rawTmdbId?.toString() ?? '';
    if (tmdbId.isEmpty) return null;

    // 2. Determinar si es película o serie para la URL de la API
    String type = 'movie';
    if (rawType != null) {
      String t = rawType.toLowerCase();
      if (t == 'tv' || t == 'serie' || t == 'series') type = 'tv';
    }

    final url = Uri.parse(
      'https://api.themoviedb.org/3/$type/$tmdbId?api_key=$apiKey&language=es-ES&append_to_response=videos,credits,images,seasons',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Creamos el objeto Movie con todos los datos necesarios para reproducir
        return Movie(
          id: data['id'] ?? 0,
          tmdbId: data['id']?.toString() ?? '',
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
      debugPrint("Error obteniendo datos de TMDB: $e");
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
        title: const Text("Mi lista", style: TextStyle(color: Colors.white)),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : watchlist.isEmpty
          ? const Center(
              child: Text(
                "Tu lista está vacía",
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: watchlist.length,
              itemBuilder: (context, index) {
                final item = watchlist[index];

                // IMPORTANTE: Usamos el campo tmdb_id que viene de tu base de datos Neon
                final dynamic tmdbIdFromDb = item['tmdb_id'] ?? item['tmdbId'];

                return InkWell(
                  onTap: () async {
                    // Mostramos un indicador de carga mientras bajamos la info de la API
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      ),
                    );

                    final movie = await _fetchFullMovieData(
                      tmdbIdFromDb,
                      item['type'],
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Quitar el loading
                      if (movie != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MovieDetailsScreen(movie: movie, user: user),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("No se pudo cargar la información"),
                          ),
                        );
                      }
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          item['image']?.toString().startsWith('http') == true
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
                        // Botón para eliminar de la lista directamente
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => provider.toggleWatchlist(
                              userId,
                              int.parse(tmdbIdFromDb.toString()),
                              item['title'],
                              item['image'],
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
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
