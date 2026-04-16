import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Importante
import 'watchlist_providers.dart';

class MyListScreen extends StatelessWidget {
  const MyListScreen({
    super.key,
  }); // Ya no necesita recibir la lista por constructor

  @override
  Widget build(BuildContext context) {
    // Obtenemos la lista directamente del Provider
    final watchlist = Provider.of<WatchlistProvider>(context).favoriteMovies;

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
      body: watchlist.isEmpty
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
                childAspectRatio: 16 / 9,
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
                          image: NetworkImage(movie['image']!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Opcional: Botón para eliminar directamente desde aquí
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => Provider.of<WatchlistProvider>(
                          context,
                          listen: false,
                        ).toggleFavorite(movie),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
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
