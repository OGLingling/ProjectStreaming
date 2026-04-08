import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/movie_model.dart';
import 'movie_details_screen.dart';

class MoviesScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const MoviesScreen({super.key, this.user});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  List<Movie> movies = [];
  bool isLoading = true;
  String? errorMessage; // Para mostrar errores amigables

  YoutubePlayerController? _ytController;

  // URL dinámica: Se adapta si el usuario pide Películas o Series específicamente
  final String apiBaseUrl =
      "https://projectstreaming-production.up.railway.app/api/movies";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({String? type}) async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Si enviamos un tipo (ej: 'Pelicula'), lo añadimos como query parameter
      final uri = type != null
          ? Uri.parse("$apiBaseUrl?type=$type")
          : Uri.parse(apiBaseUrl);

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            movies = data.map((m) => Movie.fromJson(m)).toList();
            isLoading = false;
          });

          // Inicializar Banner si hay trailer
          if (movies.isNotEmpty && movies[0].trailerUrl != null) {
            _initYoutubePlayer(movies[0].trailerUrl!);
          }
        }
      } else {
        throw Exception("Error del servidor (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Fullstack Log - Error cargando Neon: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "No se pudieron cargar los datos. Revisa tu conexión.";
        });
      }
    }
  }

  void _initYoutubePlayer(String url) {
    String? videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null) {
      // Liberar controlador previo si existe
      _ytController?.dispose();

      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: true,
          loop: true,
          hideControls: true,
          disableDragSeek: true,
          forceHD: true,
        ),
      );
    }
  }

  // Función de navegación profesional
  void _navigateToDetails(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MovieDetailsScreen(movie: movie, user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }

    if (errorMessage != null && movies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white24, size: 60),
            const SizedBox(height: 16),
            Text(errorMessage!, style: const TextStyle(color: Colors.white70)),
            TextButton(
              onPressed: () => _loadData(),
              child: const Text(
                "Reintentar",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(),
      color: Colors.red,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildVideoBanner(),
            const SizedBox(height: 10),
            _buildSection("Tendencias ahora", movies),
            _buildSection("Aclamadas por la crítica", movies.reversed.toList()),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoBanner() {
    if (movies.isEmpty) return const SizedBox.shrink();
    final mainMovie = movies[0];
    double bannerHeight = MediaQuery.of(context).size.height * 0.75;

    return GestureDetector(
      onTap: () => _navigateToDetails(mainMovie),
      child: Container(
        height: bannerHeight,
        width: double.infinity,
        child: Stack(
          children: [
            // REPRODUCTOR O IMAGEN (CON FALLBACK)
            Positioned.fill(
              child: (_ytController != null)
                  ? IgnorePointer(
                      // Evita que los clics del video bloqueen el gesto
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: 16,
                          height: 9,
                          child: YoutubePlayer(
                            controller: _ytController!,
                            showVideoProgressIndicator: false,
                          ),
                        ),
                      ),
                    )
                  : Image.network(
                      mainMovie.backdropUrl ?? mainMovie.imageUrl ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(color: Colors.black),
                    ),
            ),

            // GRADIENTES
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xFF141414),
                    ],
                    stops: [0.0, 0.2, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // CONTENIDO DEL BANNER
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      mainMovie.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 48,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _bannerButton(
                        Icons.play_arrow,
                        "Reproducir",
                        Colors.white,
                        Colors.black,
                        mainMovie,
                      ),
                      const SizedBox(width: 12),
                      _bannerButton(
                        Icons.info_outline,
                        "Información",
                        Colors.white24,
                        Colors.white,
                        mainMovie,
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

  Widget _bannerButton(
    IconData icon,
    String label,
    Color bg,
    Color txt,
    Movie movie,
  ) {
    return ElevatedButton.icon(
      onPressed: () => _navigateToDetails(movie),
      icon: Icon(icon, color: txt, size: 28),
      label: Text(
        label,
        style: TextStyle(color: txt, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        minimumSize: const Size(150, 45),
      ),
    );
  }

  Widget _buildSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 20, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: list.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _navigateToDetails(list[i]),
              child: Container(
                width: 110,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(list[i].imageUrl ?? ''),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }
}
