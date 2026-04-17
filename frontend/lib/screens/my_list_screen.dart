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

  // Función para obtener los detalles completos desde TMDB
  Future<Movie?> _fetchFullMovieData(dynamic tmdbId, String? rawType) async {
    const String apiKey = 'd8a00b94f5c00821e497b569fec9a61f';

    final String id = tmdbId?.toString() ?? '';
    if (id.isEmpty || id == 'null') return null;

    String type = 'movie';
    if (rawType != null) {
      String t = rawType.toLowerCase();
      if (t == 'tv' || t == 'serie' || t == 'series') type = 'tv';
    }

    final url = Uri.parse(
      'https://api.themoviedb.org/3/$type/$id?api_key=$apiKey&language=es-ES&append_to_response=videos,credits,images,seasons',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return Movie(
          id: data['id'] ?? 0,
          tmdbId: data['id']?.toString() ?? id,
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
      debugPrint("Error llamando a TMDB: $e");
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
        iconTheme: const IconThemeData(color: Colors.white),
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
                int crossAxisCount = constraints.maxWidth > 1200 ? 7 : 3;

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.67,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: watchlist.length,
                  itemBuilder: (context, index) {
                    final item = watchlist[index];

                    // Extraemos el ID correcto (tmdb_id de Neon o tmdbId de la lista local)
                    final dynamic idParaTMDB =
                        item['tmdb_id'] ?? item['tmdbId'];
                    final String type = item['type'] ?? 'movie';

                    return InkWell(
                      onTap: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(color: Colors.red),
                          ),
                        );

                        final movie = await _fetchFullMovieData(
                          idParaTMDB,
                          type,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
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
                              SnackBar(
                                content: Text(
                                  "No se pudo cargar la información ($idParaTMDB)",
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
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                // CORRECCIÓN: Uso de argumentos nombrados para coincidir con el Provider
                                onTap: () => provider.toggleWatchlist(
                                  userId: userId,
                                  tmdbId: idParaTMDB,
                                  title: item['title'] ?? '',
                                  image: item['image'] ?? '',
                                  type: type,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
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
                );
              },
            ),
    );
  }
}
