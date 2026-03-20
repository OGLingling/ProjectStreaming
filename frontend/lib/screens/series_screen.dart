import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo oscuro estilo Netflix/Disney+
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        title: const Text(
          "Series Disponibles",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.getMoviesByType('Serie'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Text(
                "Error al cargar las series",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final series = snapshot.data!;
          if (series.isEmpty) {
            return const Center(
              child: Text(
                "No hay series disponibles",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            // Diseño Responsivo: Ajusta el número de columnas según el ancho
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.68, // Proporción perfecta de póster
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: series.length,
            itemBuilder: (context, index) {
              final item = series[index];
              return _buildSerieCard(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildSerieCard(Map<String, dynamic> serie) {
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
            // Imagen con efecto de carga y error
            Image.network(
              serie['imageUrl'] ?? '',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[900],
                child: const Icon(
                  Icons.movie_filter,
                  color: Colors.white24,
                  size: 50,
                ),
              ),
            ),

            // Gradiente para mejorar legibilidad
            Positioned.fill(child: DecoratedBox(decoration: getGradient())),

            // Información sobre el póster
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    serie['title'] ?? 'Sin título',
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
                        "${serie['rating'] ?? 'N/A'}",
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
