import 'package:flutter/material.dart';

class MovieDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> movieData;

  const MovieDetailsScreen({super.key, required this.movieData});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el tamaño de la pantalla para que sea responsivo
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF121826),
      body: SingleChildScrollView(
        // Para que el texto no se corte en pantallas pequeñas
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PARTE SUPERIOR: IMAGEN AUTOAJUSTABLE ---
            Stack(
              children: [
                Container(
                  height:
                      size.height * 0.45, // 45% de la pantalla para la imagen
                  width: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      // Usamos la misma lógica híbrida (URL o Assets)
                      image: movieData['imageUrl'].startsWith('http')
                          ? NetworkImage(movieData['imageUrl'])
                          : AssetImage('assets/images/${movieData['imageUrl']}')
                                as ImageProvider,
                      fit: BoxFit
                          .cover, // <--- Esto hace que la imagen se autoajuste
                    ),
                  ),
                ),
                // Graduación oscura para que el texto resalte (Netflix Style)
                Container(
                  height: size.height * 0.45,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0xFF121826), // Se funde con el color de fondo
                      ],
                    ),
                  ),
                ),
                // Botón de atrás
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),

            // --- SECCIÓN DE INFORMACIÓN ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          movieData['title'] ?? 'Sin título',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.yellow[700],
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${movieData['rating']} ★',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${movieData['category']} • ${movieData['releaseDate'].toString().substring(0, 4)}",
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "SINOPSIS",
                    style: TextStyle(
                      color: Colors.grey,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    movieData['description'] ??
                        'No hay descripción disponible.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 50), // Espacio final
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
