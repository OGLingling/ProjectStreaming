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
  final ScrollController _scrollController = ScrollController();
  YoutubePlayerController? _ytController;

  final String tmdbApiKey = "d8a00b94f5c00821e497b569fec9a61f";
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
        List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            movies = data.map((m) => Movie.fromJson(m)).toList();
            isLoading = false;
          });
          // Usamos el tmdbId real guardado en tu DB
          if (movies.isNotEmpty) _loadTrailer(movies[0].tmdbId ?? '');
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _loadTrailer(String tmdbId) async {
    if (tmdbId.isEmpty) return;
    final url =
        "https://api.themoviedb.org/3/movie/$tmdbId/videos?api_key=$tmdbApiKey&language=es-ES";
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List videos = data['results'];
        final trailer = videos.firstWhere(
          (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
          orElse: () => videos.isNotEmpty ? videos[0] : null,
        );
        if (trailer != null && mounted) _initYoutube(trailer['key']);
      }
    } catch (e) {
      debugPrint("Trailer Error: $e");
    }
  }

  void _initYoutube(String key) {
    _ytController?.dispose();
    _ytController = YoutubePlayerController(
      initialVideoId: key,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: true,
        loop: true,
        hideControls: true,
        disableDragSeek: true, // Crucial para no bloquear scroll
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : ListView(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              children: [
                _buildHeroBanner(size),
                const SizedBox(height: 20),
                _buildSection("Tendencias ahora", movies),
                _buildSection(
                  "Aclamadas por la crítica",
                  movies.reversed.toList(),
                ),
                const SizedBox(height: 100),
              ],
            ),
    );
  }

  Widget _buildHeroBanner(Size size) {
    if (movies.isEmpty) return const SizedBox.shrink();
    final movie = movies[0];

    return SizedBox(
      height: size.height * 0.8,
      child: Stack(
        children: [
          // Capa de Video bloqueada para gestos (Permite scroll)
          Positioned.fill(
            child: IgnorePointer(
              child: _ytController != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: size.width,
                        height: size.height * 0.8,
                        child: YoutubePlayer(controller: _ytController!),
                      ),
                    )
                  : Image.network(movie.backdropUrl ?? '', fit: BoxFit.cover),
            ),
          ),
          // Gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xFF141414),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
          // Botones (Fuera del IgnorePointer para que funcionen)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  movie.title.toUpperCase(),
                  style: GoogleFonts.bebasNeue(
                    color: Colors.white,
                    fontSize: 50,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _netflixButton(
                      Icons.play_arrow,
                      "Reproducir",
                      Colors.white,
                      Colors.black,
                      movie,
                    ),
                    const SizedBox(width: 15),
                    _netflixButton(
                      Icons.info_outline,
                      "Información",
                      Colors.grey.withOpacity(0.5),
                      Colors.white,
                      movie,
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

  Widget _netflixButton(
    IconData icon,
    String text,
    Color bg,
    Color textCol,
    Movie movie,
  ) {
    return ElevatedButton.icon(
      onPressed: () => _navigateToDetails(movie),
      icon: Icon(icon, color: textCol),
      label: Text(
        text,
        style: TextStyle(color: textCol, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        minimumSize: const Size(150, 45),
      ),
    );
  }

  void _navigateToDetails(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => MovieDetailsScreen(movie: movie, user: widget.user),
      ),
    );
  }

  Widget _buildSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: list.length,
            itemBuilder: (context, i) => MovieCard(
              movie: list[i],
              onDetail: () => _navigateToDetails(list[i]),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ytController?.dispose();
    super.dispose();
  }
}

// COMPONENTE PARA EL EFECTO HOVER Y POPUP
class MovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback onDetail;
  const MovieCard({super.key, required this.movie, required this.onDetail});

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onDetail,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 12),
          width: isHovered ? 130 : 110, // Efecto escala
          curve: Curves.easeInOut,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  widget.movie.imageUrl ?? '',
                  fit: BoxFit.cover,
                  height: 160,
                ),
              ),
              if (isHovered)
                Positioned(
                  bottom: -40,
                  left: -10,
                  right: -10,
                  child: Material(
                    elevation: 10,
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.movie.title,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "Ver detalles",
                            style: TextStyle(color: Colors.red, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
