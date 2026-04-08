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

  // Controlador para YouTube
  YoutubePlayerController? _ytController;
  bool _isPlayerReady = false;

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
            movies = data.map((m) => Movie.fromJson(m)).toList();
            isLoading = false;
          });
          // Si la primera película tiene trailerUrl, inicializamos el reproductor
          if (movies.isNotEmpty && movies[0].trailerUrl != null) {
            _initYoutubePlayer(movies[0].trailerUrl!);
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _initYoutubePlayer(String url) {
    // Extraemos el ID de YouTube de la URL (ej: watch?v=videoId)
    String? videoId = YoutubePlayer.convertUrlToId(url);

    if (videoId != null) {
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: true, // Netflix reproduce en mute por defecto
          loop: true,
          isLive: false,
          forceHD: true,
          disableDragSeek: true,
          hideControls: true, // Para que parezca un banner, no un video de YT
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildVideoBanner(),
                  const SizedBox(height: 10),
                  _buildSection("Tendencias ahora", movies),
                  _buildSection(
                    "Aclamadas por la crítica",
                    movies.reversed.toList(),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildVideoBanner() {
    if (movies.isEmpty) return const SizedBox.shrink();
    final mainMovie = movies[0];
    double bannerHeight = MediaQuery.of(context).size.height * 0.8;

    return Container(
      height: bannerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          // REPRODUCTOR O IMAGEN
          Positioned.fill(
            child: (_ytController != null)
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: 16,
                      height: 9,
                      child: YoutubePlayer(
                        controller: _ytController!,
                        showVideoProgressIndicator: false,
                      ),
                    ),
                  )
                : Image.network(
                    mainMovie.backdropUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(color: Colors.black),
                  ),
          ),

          // GRADIENTES NETFLIX
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xFF141414),
                  ],
                  stops: [0.0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // TEXTO Y BOTONES
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Column(
              children: [
                Text(
                  mainMovie.title.toUpperCase(),
                  style: GoogleFonts.bebasNeue(
                    color: Colors.white,
                    fontSize: 50,
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
                      Colors.white30,
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
      onPressed: () {}, // Navegación a detalles
      icon: Icon(icon, color: txt),
      label: Text(
        label,
        style: TextStyle(color: txt, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        minimumSize: const Size(150, 45),
      ),
    );
  }

  Widget _buildSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
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
            itemCount: list.length,
            itemBuilder: (context, i) => Container(
              width: 110,
              margin: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                image: DecorationImage(
                  image: NetworkImage(list[i].imageUrl ?? ''),
                  fit: BoxFit.cover,
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
