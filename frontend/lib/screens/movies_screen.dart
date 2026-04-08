import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isMuted = true;
  final ScrollController _scrollController = ScrollController();

  // Cambiado a la ruta correcta que definimos en el backend enriquecido
  final String apiBaseUrl =
      "https://projectstreaming-production.up.railway.app/api/movies";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final response = await http.get(Uri.parse(apiBaseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            // Validamos que el mapeo sea correcto según el nuevo modelo enriquecido
            movies = data.map((m) => Movie.fromJson(m)).toList();
            isLoading = false;
          });
          if (movies.isNotEmpty) _initVideoBanner();
        }
      }
    } catch (e) {
      debugPrint("Error cargando películas: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _initVideoBanner() {
    // URL de respaldo segura
    String url =
        "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/DulceHogar.mp4";

    _videoController = VideoPlayerController.networkUrl(WebUri(url))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _isVideoInitialized = true);
              _videoController?.setVolume(0.0);
              _videoController?.setLooping(true);
              _videoController?.play();
            }
          })
          .catchError((error) => debugPrint("Video error: $error"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      // ELIMINADO: appBar duplicado.
      // Ahora el contenido sube hasta el tope y respeta el AppBar del MainScreen.
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : movies.isEmpty
          ? const Center(
              child: Text(
                "No hay contenido disponible",
                style: TextStyle(color: Colors.white),
              ),
            )
          : VisibilityDetector(
              key: const Key('movies-list-key'),
              onVisibilityChanged: (info) {
                if (info.visibleFraction > 0.5)
                  _videoController?.play();
                else
                  _videoController?.pause();
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVideoBanner(),
                    const SizedBox(height: 10),
                    _buildSection("Tendencias ahora", movies),
                    _buildSection(
                      "Aclamadas por la crítica",
                      movies.reversed.toList(),
                    ),
                    const SizedBox(
                      height: 100,
                    ), // Espacio extra para el Bottom Nav
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildVideoBanner() {
    if (movies.isEmpty) return const SizedBox.shrink();
    final mainMovie = movies[0];

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.70,
      child: Stack(
        children: [
          Positioned.fill(
            child: _isVideoInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                : (mainMovie.backdropUrl != null
                      ? Image.network(mainMovie.backdropUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.black)),
          ),
          // Gradiente Pro para mezclar con el fondo negro
          const Positioned.fill(
            child: DecoratedBox(
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
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  mainMovie.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bebasNeue(
                    color: Colors.white,
                    fontSize: 42,
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
                    const SizedBox(width: 15),
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
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailsScreen(movieData: movie.toJson()),
        ),
      ),
      icon: Icon(icon, color: txt),
      label: Text(
        label,
        style: TextStyle(color: txt, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        minimumSize: const Size(140, 40),
      ),
    );
  }

  Widget _buildSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.length,
            itemBuilder: (context, i) => _movieCard(list[i]),
          ),
        ),
      ],
    );
  }

  Widget _movieCard(Movie movie) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailsScreen(movieData: movie.toJson()),
        ),
      ),
      child: Container(
        width: 115,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          image: DecorationImage(
            image: NetworkImage(
              movie.imageUrl ?? 'https://via.placeholder.com/500',
            ),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
