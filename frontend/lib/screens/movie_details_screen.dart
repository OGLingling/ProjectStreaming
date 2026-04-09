import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movie_model.dart';
import 'video_player_screen.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;
  final Map<String, dynamic>? user;

  const MovieDetailsScreen({super.key, required this.movie, this.user});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  // Lógica de navegación pro: Maneja ambos IDs y tipos de contenido
  void _navigateToPlayer(BuildContext context) {
    final String? tmdbId = widget.movie.tmdbId?.toString();
    final String? imdbId = widget.movie.imdbId;

    if (tmdbId != null || imdbId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            tmdbId: tmdbId,
            imdbId: imdbId,
            title: widget.movie.title,
            type: widget.movie.type ?? 'movie',
          ),
        ),
      );
    } else {
      _showErrorSnackBar(context, "Contenido no disponible temporalmente.");
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header con efecto de colapso profesional
          SliverAppBar(
            expandedHeight: size.height * 0.45,
            backgroundColor: const Color(0xFF141414),
            elevation: 0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero Image
                  Image.network(
                    widget.movie.backdropUrl ?? widget.movie.imageUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: Colors.grey[900]),
                  ),
                  // Gradiente dinámico (Netflix signature)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          Color(0xFF141414),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenido de la información
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Título principal
                  Text(
                    widget.movie.title,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Fila de Metadatos (Año, Calificación, Calidad)
                  Row(
                    children: [
                      Text(
                        widget.movie.releaseDate?.substring(0, 4) ?? "2024",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          "16+",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "4K Ultra HD",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // BOTÓN REPRODUCIR (Primario)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToPlayer(context),
                      icon: const Icon(Icons.play_arrow, size: 30),
                      label: const Text(
                        "Reproducir",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // BOTÓN DESCARGAR (Secundario)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _showErrorSnackBar(
                        context,
                        "Función de descarga no disponible.",
                      ),
                      icon: const Icon(Icons.download, size: 24),
                      label: const Text(
                        "Descargar",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[850],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sinopsis
                  Text(
                    widget.movie.description ?? 'Sin descripción disponible.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Información de Cast/Género
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      children: [
                        const TextSpan(
                          text: "Géneros: ",
                          style: TextStyle(color: Colors.white60),
                        ),
                        TextSpan(
                          text: widget.movie.category ?? 'Acción, Drama',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Fila de acciones sociales
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.add, "Mi lista"),
                      _buildActionButton(
                        Icons.thumb_up_alt_outlined,
                        "Calificar",
                      ),
                      _buildActionButton(Icons.share, "Compartir"),
                    ],
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
