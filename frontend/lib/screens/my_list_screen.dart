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

  // Función para obtener los datos detallados de TMDB
  Future<Movie?> _fetchFullMovieData(int id, String type) async {
    const String apiKey = 'd8a00b94f5c00821e497b569fec9a61f';
    final String category = type == 'tv' ? 'tv' : 'movie';
    final url = Uri.parse(
      'https://api.themoviedb.org/3/$category/$id?api_key=$apiKey&language=es-ES&append_to_response=videos,credits,images,seasons',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Mapeo manual para evitar errores de argumentos en el constructor
        return Movie(
          id: data['id'],
          tmdbId: data['id'].toString(),
          title: data['title'] ?? data['name'] ?? '',
          description: data['overview'] ?? 'Sin sinopsis disponible',
          releaseDate: data['release_date'] ?? data['first_air_date'] ?? '',
          imageUrl: data['poster_path'] ?? '',
          backdropUrl: data['backdrop_path'] ?? '',
          rating: (data['vote_average'] as num).toDouble(),
          category: '',
          type: type, // Asignamos el tipo (movie/tv) correctamente
          seasons: [], // Si tu modelo maneja temporadas, podrías mapearlas aquí
        );
      }
    } catch (e) {
      debugPrint("Error en Mi Lista: $e");
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
                "Aún no tienes nada en tu lista",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // Configuración para posters pequeños (7 en web, 3 en móvil)
                int crossAxisCount = constraints.maxWidth > 1200 ? 7 : 3;

                return GridView.builder(
                  padding: const EdgeInsets.all(15),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.67, // Proporción vertical estética
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: watchlist.length,
                  itemBuilder: (context, index) {
                    final item = watchlist[index];
                    final int movieId =
                        int.tryParse(item['id'].toString()) ?? 0;
                    final String type = item['type'] ?? 'tv';

                    // Construcción de la URL de imagen para evitar posters vacíos
                    String imageUrl = item['image'] ?? '';
                    if (!imageUrl.startsWith('http') && imageUrl.isNotEmpty) {
                      imageUrl = 'https://image.tmdb.org/t/p/w500$imageUrl';
                    }

                    return InkWell(
                      onTap: () async {
                        // Indicador de carga antes de navegar
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(color: Colors.red),
                          ),
                        );

                        final fullMovie = await _fetchFullMovieData(
                          movieId,
                          type,
                        );

                        if (context.mounted) {
                          Navigator.pop(context); // Quitar el diálogo de carga
                          if (fullMovie != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MovieDetailsScreen(
                                  movie: fullMovie,
                                  user: user,
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
                            // Imagen del poster
                            imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(color: Colors.grey[900]),
                                  )
                                : Container(color: Colors.grey[900]),
                            // Botón para eliminar de la lista
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => provider.toggleWatchlist(
                                  userId,
                                  movieId,
                                  item['title'] ?? '',
                                  imageUrl,
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
                    );
                  },
                );
              },
            ),
    );
  }
}
