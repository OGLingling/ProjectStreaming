import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'watchlist_providers.dart';

class MyListScreen extends StatelessWidget {
  final String userId; // Necesitamos el ID para filtrar en la BD
  const MyListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WatchlistProvider>(context);
    final watchlist = provider.favoriteMovies;

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
                crossAxisCount: 3,
                childAspectRatio: 2 / 3, // Ajustado para posters
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: watchlist.length,
              itemBuilder: (context, index) {
                final movie = watchlist[index];
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(movie['image'] ?? ''),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => provider.toggleFavorite(movie, userId),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
