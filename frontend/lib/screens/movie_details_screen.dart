import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movie_model.dart';
import 'video_player_screen.dart';

class MovieDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> movieData;

  const MovieDetailsScreen({super.key, required this.movieData});

  void _playVideo(BuildContext context, String id, String title) {
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
    final movie = Movie.fromJson(movieData);
    final String? movieId = movie.imdbId;

    // Priorizamos backdropUrl para el banner estilo Netflix
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
            // ÁREA DEL BANNER ESTILO NETFLIX
            Stack(
              children: [
                // 1. Imagen de Fondo
                AspectRatio(
                  aspectRatio:
                      16 / 11, // Un poco más alto para mejor impacto visual
                  child: !hasValidCoverImg
                      ? Container(color: Colors.grey[900])
                      : (coverImg.startsWith('http')
                            ? Image.network(coverImg, fit: BoxFit.cover)
                            : Image.asset(coverImg, fit: BoxFit.cover)),
                ),
                // 2. Gradiente Vertical (El secreto del look Netflix)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.4, 0.7, 1.0],
                        colors: [
                          Colors.black.withOpacity(
                            0.5,
                          ), // Sombra suave arriba para el botón back
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                          const Color(
                            0xFF141414,
                          ), // Negro sólido que funde con el body
                        ],
                      ),
                    ),
                  ),
                ),
                // 3. Contenido sobre el banner (Título y Play)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title.toUpperCase(),
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // BOTÓN REPRODUCIR ANCHO (Full Width Estilo Móvil)
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _playVideo(context, movieId ?? '', movie.title),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.play_arrow, size: 30),
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

            // SECCIÓN DE DETALLES ABAJO DEL BANNER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        "98% para ti", // Dato dummy para look real
                        style: GoogleFonts.roboto(
                          color: const Color(0xFF46D369),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Text(
                        movie.releaseDate?.toString().substring(0, 4) ?? '2026',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white60),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          "16+",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Text(
                        movie.category ?? 'Serie',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // LA DESCRIPCIÓN
                  Text(
                    movie.description ?? 'Sin descripción disponible.',
                    style: GoogleFonts.roboto(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 25),
                  // INFO DE REPARTO / GÉNEROS (Opcional para más realismo)
                  const Text(
                    "Géneros: Suspenso, Drama, Terror",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
