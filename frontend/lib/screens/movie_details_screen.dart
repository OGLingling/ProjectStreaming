import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'video_player_screen.dart'; // Importación verificada

class MovieDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> movieData;

  const MovieDetailsScreen({super.key, required this.movieData});

  // FUNCIÓN PARA REPRODUCIR EL VIDEO DESDE SUPABASE
  void _playVideo(BuildContext context) {
    // Extraemos la URL de Supabase desde movieData
    final String? videoUrl = movieData['videoUrl'];

    if (videoUrl != null && videoUrl.isNotEmpty) {
      // NAVEGACIÓN ACTIVA: Pasamos la URL a tu pantalla de reproductor
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoUrl: videoUrl,
            title: movieData['title'] ?? 'Sin título',
          ),
        ),
      );
    } else {
      // Feedback visual si no hay link en la base de datos
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Error: No se encontró el link del video en la base de datos.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String coverImg =
        (movieData['backdropUrl'] ?? movieData['imageUrl'] ?? '')
            .toString()
            .trim();
    final String title = movieData['title'] ?? 'Sin título';
    final String description = movieData['description'] ?? '';
    final String category = movieData['category'] ?? '';
    final double rating = (movieData['rating'] as num?)?.toDouble() ?? 0.0;
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
          children: [
            // ÁREA DEL BANNER (Imagen completa 16:9)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  // 1. IMAGEN DE FONDO
                  Positioned.fill(
                    child: !hasValidCoverImg
                        ? const SizedBox.expand()
                        : (coverImg.startsWith('http')
                              ? Image.network(coverImg, fit: BoxFit.cover)
                              : (coverImg.startsWith('assets/')
                                    ? Image.asset(coverImg, fit: BoxFit.cover)
                                    : const SizedBox.expand())),
                  ),

                  // 2. GRADIENTE DE PROTECCIÓN (Estilo Netflix: Oscuro a la izquierda)
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

                  // 3. CAPA DE INFORMACIÓN (Título, Sinopsis, Botón)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título (Área Azul)
                        Text(
                          title.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Sinopsis (Área Verde)
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.45,
                          child: Text(
                            description,
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

                        // Rating y Categoría
                        Row(
                          children: [
                            Text(
                              "$rating Calificación",
                              style: const TextStyle(
                                color: Color(0xFF46D369),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              category,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),

                        // BOTÓN DE REPRODUCIR (Área Blanca - Tamaño reducido)
                        SizedBox(
                          width: 150,
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: () => _playVideo(
                              context,
                            ), // <--- CONEXIÓN CON REPRODUCTOR
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 5,
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

            // Contenedor para contenido extra debajo si lo necesitas
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
