import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movie_model.dart';
import 'video_player_screen.dart';

class MovieDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> movieData;

  const MovieDetailsScreen({super.key, required this.movieData});

  // FUNCIÓN ACTUALIZADA: Maneja videoUrl directo y Streams de Addons
  void _playVideo(BuildContext context, String url, String title) {
    if (url.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(videoUrl: url, title: title),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: El link del video no es válido."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Convertimos movieData al modelo Movie para mayor seguridad
    final movie = Movie.fromJson(movieData);

    final String coverImg = (movie.backdropUrl ?? movie.imageUrl ?? '').trim();
    final bool hasValidCoverImg =
        coverImg.isNotEmpty && coverImg.toLowerCase() != 'null';

    // Prioridad de URL: 1. videoUrl directo, 2. Primer Stream del Addon
    final String? primaryVideoUrl =
        movie.videoUrl ??
        (movie.streams != null && movie.streams!.isNotEmpty
            ? movie.streams![0].url
            : null);

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
                          stops: const [0.0, 0.5, 1.0],
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
                        const SizedBox(height: 10),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.45,
                          child: Text(
                            movie.description ?? 'Sin descripción disponible.',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              "${movie.rating} Calificación",
                              style: const TextStyle(
                                color: Color(0xFF46D369),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              movie.category ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        if (primaryVideoUrl != null)
                          SizedBox(
                            width: 150,
                            height: 38,
                            child: ElevatedButton.icon(
                              onPressed: () => _playVideo(
                                context,
                                primaryVideoUrl,
                                movie.title,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              icon: const Icon(Icons.play_arrow, size: 24),
                              label: const Text(
                                "Reproducir",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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

            // SECCIÓN DE STREAMS / OPCIONES (Si es de un Addon)
            if (movie.streams != null && movie.streams!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Opciones de Calidad",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: movie.streams!.map((stream) {
                        return ChoiceChip(
                          label: Text(stream.quality),
                          selected: false,
                          onSelected: (_) =>
                              _playVideo(context, stream.url, movie.title),
                          backgroundColor: Colors.grey[800],
                          labelStyle: const TextStyle(color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            // Espacio inferior
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
