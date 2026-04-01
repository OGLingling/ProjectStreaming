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
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // --- 1. BACKDROP A PANTALLA COMPLETA ---
            SizedBox(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.75,
              child: !hasValidCoverImg
                  ? Container(color: Colors.grey[900])
                  : (coverImg.startsWith('http')
                        ? Image.network(
                            coverImg,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Image.asset(
                            coverImg,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )),
            ),

            // --- 2. GRADIENTES SOBRE LA IMAGEN ---
            SizedBox(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.75,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.85), // Oscuro a la izquierda
                      Colors.transparent, // Transparente a la derecha
                    ],
                  ),
                ),
              ),
            ),
            // Gradiente inferior para transición suave al negro
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, const Color(0xFF141414)],
                  ),
                ),
              ),
            ),

            // --- 3. CONTENIDO SUPERPUESTO SOBRE LA IMAGEN ---
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 40, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // TÍTULO
                      Text(
                        movie.title.toUpperCase(),
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // METADATOS
                      Row(
                        children: [
                          Text(
                            "98% para ti",
                            style: const TextStyle(
                              color: Color(0xFF46D369),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            movie.releaseDate.toString().substring(0, 4),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 14),
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
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            movie.category ?? 'Terror / Horror',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // DESCRIPCIÓN (limitada para no tapar la imagen)
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.52,
                        child: Text(
                          movie.description ?? 'Sin descripción disponible.',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.5,
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
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 18),

                      // BOTÓN REPRODUCIR
                      SizedBox(
                        width: 200,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _playVideo(context, movieId ?? '', movie.title),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow, size: 26),
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
            ),

            // --- 4. SECCIÓN INFERIOR (debajo del banner) ---
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.72,
                left: 20,
                right: 20,
                bottom: 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Puedes agregar secciones extra aquí:
                  // "Más información", episodios, reparto, etc.
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
