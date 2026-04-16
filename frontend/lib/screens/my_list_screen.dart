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

  // Función crítica: Obtiene la data real de TMDB usando el ID guardado en tu DB
  Future<Movie?> _fetchFullMovieData(dynamic rawId, String? rawType) async {
    const String apiKey = 'd8a00b94f5c00821e497b569fec9a61f';

    // 1. Limpieza de ID: Aseguramos que sea un entero puro
    final int? movieId = int.tryParse(rawId.toString());
    if (movieId == null) return null;

    // 2. Normalización de Tipo: TMDB solo entiende 'movie' o 'tv'
    String type = 'movie';
    if (rawType != null) {
      String t = rawType.toLowerCase();
      if (t == 'tv' || t == 'serie' || t == 'series') type = 'tv';
    }

    final url = Uri.parse(
      'https://api.themoviedb.org/3/$type/$movieId?api_key=$apiKey&language=es-ES&append_to_response=videos,credits,images,seasons',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Mapeo manual completo para que la pantalla de detalles tenga TODO
        return Movie(
          id: data['id'],
          tmdbId: data['id'].toString(),
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
      debugPrint("Error cargando desde Mi Lista: $e");
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
        title: const Text("Mi lista", style: TextStyle(color: Colors.white)),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : watchlist.isEmpty
          ? const Center(
              child: Text(
                "Tu lista está vacía",
                style: TextStyle(color: Colors.white),
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

                return InkWell(
                  onTap: () async {
                    // Mostrar loading mientras consultamos TMDB
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    // Buscamos la info real usando el ID y Tipo de tu DB
                    final movie = await _fetchFullMovieData(
                      item['contentId'],
                      item['type'],
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Quitar loading
                      if (movie != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MovieDetailsScreen(movie: movie, user: user),
                          ),
                        );
                      }
                    }
                  },
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item['image']?.toString().startsWith('http') == true
                              ? item['image']
                              : 'https://image.tmdb.org/t/p/w500${item['image']}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey[900],
                                child: const Icon(
                                  Icons.movie,
                                  color: Colors.white,
                                ),
                              ),
                        ),
                      ),
                      // Botón eliminar
                      Positioned(
                        top: 5,
                        right: 5,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => provider.toggleWatchlist(
                            userId,
                            int.parse(item['contentId'].toString()),
                            item['title'],
                            item['image'],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
