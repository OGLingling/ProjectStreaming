import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PeliculasScreen extends StatefulWidget {
  const PeliculasScreen({super.key});

  @override
  State<PeliculasScreen> createState() => _PeliculasScreenState();
}

class _PeliculasScreenState extends State<PeliculasScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo oscuro consistente con SeriesScreen
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          "Películas",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
        // Mantenemos tu lógica de filtro para películas
        future: ApiService.getMoviesByType('movie'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Text(
                "Error al cargar películas",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final peliculas = snapshot.data!;
          if (peliculas.isEmpty) {
            return const Center(
              child: Text(
                "No hay películas disponibles",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            // Diseño Responsivo idéntico al de Series
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: peliculas.length,
            itemBuilder: (context, index) {
              final item = peliculas[index];
              return _buildMovieCard(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagen del póster
            Image.network(
              movie['imageUrl'] ?? '',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[900],
                child: const Icon(
                  Icons.movie_creation_outlined,
                  color: Colors.white24,
                  size: 50,
                ),
              ),
            ),

            // Gradiente mejorado para legibilidad del título
            Positioned.fill(child: DecoratedBox(decoration: getGradient())),

            // Información (Título y Rating)
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    movie['title'] ?? 'Sin título',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${movie['rating'] ?? '0.0'}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration getGradient() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.black.withOpacity(0.9),
          Colors.black.withOpacity(0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6],
      ),
    );
  }
}
