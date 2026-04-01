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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculamos la altura real de la imagen 16:9 al ancho de pantalla
          final double screenWidth = constraints.maxWidth;
          final double imageHeight = screenWidth * (9 / 16);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- STACK: IMAGEN + GRADIENTES + CONTENIDO SUPERPUESTO ---
                SizedBox(
                  width: screenWidth,
                  height: imageHeight,
                  child: Stack(
                    children: [
                      // IMAGEN sin recorte, ajustada al ancho
                      Positioned.fill(
                        child: !hasValidCoverImg
                            ? Container(color: Colors.grey[900])
                            : (coverImg.startsWith('http')
                                  ? Image.network(
                                      coverImg,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )
                                  : Image.asset(
                                      coverImg,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )),
                      ),

                      // GRADIENTE HORIZONTAL (izquierda oscura, derecha transparente)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              stops: const [0.0, 0.45, 0.75],
                              colors: [
                                Colors.black.withOpacity(0.92),
                                Colors.black.withOpacity(0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // GRADIENTE VERTICAL SUPERIOR (para AppBar legible)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: imageHeight * 0.25,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // GRADIENTE VERTICAL INFERIOR (fusión con negro)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: imageHeight * 0.45,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xFF141414)],
                            ),
                          ),
                        ),
                      ),

                      // CONTENIDO SUPERPUESTO (parte inferior izquierda)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 40, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // TÍTULO
                              Text(
                                movie.title.toUpperCase(),
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // METADATOS
                              Row(
                                children: [
                                  const Text(
                                    "98% para ti",
                                    style: TextStyle(
                                      color: Color(0xFF46D369),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    movie.releaseDate?.toString().substring(
                                          0,
                                          4,
                                        ) ??
                                        '2026',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white60),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: const Text(
                                      "16+",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    movie.category ?? 'Terror / Horror',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // DESCRIPCIÓN
                              SizedBox(
                                width: screenWidth * 0.50,
                                child: Text(
                                  movie.description ??
                                      'Sin descripción disponible.',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),

                              // GÉNEROS
                              if (movie.category != null)
                                Text(
                                  "Géneros: ${movie.category}",
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              const SizedBox(height: 16),

                              // BOTÓN REPRODUCIR
                              SizedBox(
                                width: 180,
                                height: 40,
                                child: ElevatedButton.icon(
                                  onPressed: () => _playVideo(
                                    context,
                                    movieId ?? '',
                                    movie.title,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  icon: const Icon(Icons.play_arrow, size: 24),
                                  label: const Text(
                                    "Reproducir",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Espacio extra mínimo debajo si quieres agregar más secciones
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
