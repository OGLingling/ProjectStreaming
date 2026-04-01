import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movie_model.dart';
import 'video_player_screen.dart';

class MovieDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> movieData;

  const MovieDetailsScreen({super.key, required this.movieData});

  void _playVideo(BuildContext context, String id, String title) {
    // Quitamos espacios en blanco
    final cleanId = id.trim();

    if (cleanId.isNotEmpty && cleanId != 'null') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VideoPlayerScreen(imdbId: cleanId, title: title),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Error: Esta película no tiene un ID de IMDB configurado.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Convertimos el mapa a objeto Movie usando tu modelo actualizado
    final movie = Movie.fromJson(movieData);

    // Usamos únicamente imdbId que es el que definiste en Prisma
    final String? movieId = movie.imdbId;

    final String coverImg = (movie.backdropUrl ?? movie.imageUrl ?? '').trim();
    final bool hasValidCoverImg =
        coverImg.isNotEmpty && coverImg.toLowerCase() != 'null';

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ÁREA DEL BANNER
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: !hasValidCoverImg
                        ? Container(color: Colors.grey[900])
                        : (coverImg.startsWith('http')
                              ? Image.network(coverImg, fit: BoxFit.cover)
                              : Image.asset(coverImg, fit: BoxFit.cover)),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withOpacity(0.9),
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie.title.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 15),
                        // BOTÓN REPRODUCIR
                        SizedBox(
                          width: 160,
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: () => _playVideo(
                              context,
                              movieId ?? '', // Si es nulo, envía string vacío
                              movie.title,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow, size: 28),
                            label: const Text(
                              "Reproducir",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // INFORMACIÓN ADICIONAL
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "${movie.rating} Calificación",
                        style: const TextStyle(
                          color: Color(0xFF46D369),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Text(
                        movie.category ?? 'Película',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    movie.description ?? 'Sin descripción disponible.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
