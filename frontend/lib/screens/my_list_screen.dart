import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tmdb_service.dart';
import 'movie_details_screen.dart';
import 'watchlist_providers.dart';

class MyListScreen extends StatelessWidget {
  final String userId;
  final Map<String, dynamic>? user;

  const MyListScreen({super.key, required this.userId, this.user});

  // NOTA: Hemos eliminado _fetchFullMovieData de aquí porque ahora
  // usamos TmdbService.getMovieDetails para mantener el código limpio.

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

                    // --- LÓGICA DE IDs SINCRONIZADA CON TU BACKEND ---
                    // 1. tmdb_id: Para la API de TMDB (Evita el error 'null')
                    final dynamic tmdbIdForApi = item['tmdb_id'];

                    // 2. id: El contentId interno de Neon (Para poder eliminar)
                    final dynamic internalDbId = item['id'];

                    final String type = item['type'] ?? 'movie';

                    return InkWell(
                      onTap: () async {
                        if (tmdbIdForApi == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Error: ID de TMDB no encontrado"),
                            ),
                          );
                          return;
                        }

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(color: Colors.red),
                          ),
                        );

                        // 2. USAMOS EL SERVICIO CENTRALIZADO
                        final movie = await TmdbService.getMovieDetails(
                          tmdbIdForApi,
                          type,
                        );

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
                            // BOTÓN PARA ELIMINAR CORREGIDO
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  // Enviamos el internalDbId (el 36 de tu DB)
                                  // para que el backend sepa qué fila borrar
                                  provider.toggleWatchlist(
                                    userId,
                                    internalDbId,
                                    item['title'] ?? '',
                                    item['image'] ?? '',
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
}
