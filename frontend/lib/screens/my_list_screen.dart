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

  // Función para obtener los datos reales de TMDB usando el ID guardado
  Future<Movie?> _fetchFullMovieData(int id, String type) async {
    const String apiKey = 'd8a00b94f5c00821e497b569fec9a61f';
    final String category = (type == 'tv' || type == 'serie') ? 'tv' : 'movie';

    final url = Uri.parse(
      'https://api.themoviedb.org/3/$category/$id?api_key=$apiKey&language=es-ES&append_to_response=videos,credits,images,seasons',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Construimos el objeto Movie con todos los campos que necesita MovieDetailsScreen
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
          seasons: data['seasons'] ?? [], // Importante para series como Re:Zero
        );
      } else {
        debugPrint("Error en API TMDB: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error de conexión en Mi Lista: $e");
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
                // Ajuste de columnas: 7 en pantallas grandes, 3 en móviles
                int crossAxisCount = constraints.maxWidth > 1200 ? 7 : 3;

                return GridView.builder(
                  padding: const EdgeInsets.all(15),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.67,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: watchlist.length,
                  itemBuilder: (context, index) {
                    final item = watchlist[index];

                    // Validamos el ID para que no sea null
                    final int movieId =
                        int.tryParse(item['id'].toString()) ??
                        int.tryParse(item['contentId'].toString()) ??
                        0;
                    final String type = item['type'] ?? 'tv';

                    // Corregimos la URL de la imagen si viene incompleta
                    String imageUrl = item['image'] ?? '';
                    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
                      imageUrl = 'https://image.tmdb.org/t/p/w500$imageUrl';
                    }

                    return InkWell(
                      onTap: () async {
                        // 1. Mostrar loading
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(color: Colors.red),
                          ),
                        );

                        // 2. Obtener datos reales
                        final fullMovie = await _fetchFullMovieData(
                          movieId,
                          type,
                        );

                        if (context.mounted) {
                          Navigator.pop(context); // Quitar loading

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
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "No se pudo cargar la información",
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
                            // El Poster
                            imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              color: Colors.grey[900],
                                              child: const Icon(
                                                Icons.movie,
                                                color: Colors.white24,
                                              ),
                                            ),
                                  )
                                : Container(color: Colors.grey[900]),

                            // Botón X para eliminar
                            Positioned(
                              top: 5,
                              right: 5,
                              child: GestureDetector(
                                onTap: () => provider.toggleWatchlist(
                                  userId,
                                  movieId,
                                  item['title'] ?? '',
                                  item['image'] ?? '',
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
                );
              },
            ),
    );
  }
}
