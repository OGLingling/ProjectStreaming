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
  bool _isMuted = true;

  // IMPORTANTE: Asegúrate de poner tu API KEY real aquí
  final String tmdbApiKey = "TU_API_KEY_TMDB";
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
          if (movies.isNotEmpty) _loadTrailer(movies[0].id.toString());
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _loadTrailer(String movieId) async {
    final url =
        "https://api.themoviedb.org/3/movie/$movieId/videos?api_key=$tmdbApiKey&language=es-ES";
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
    setState(() {
      _ytController = YoutubePlayerController(
        initialVideoId: key,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: true,
          loop: true,
          hideControls: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ListView(
                controller: _scrollController,
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
          // FONDO (Video o Imagen)
          Positioned.fill(
            child: _ytController != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: size.width,
                      height: size.height * 0.8,
                      child: YoutubePlayer(
                        controller: _ytController!,
                        showVideoProgressIndicator: false,
                      ),
                    ),
                  )
                : Image.network(
                    movie.backdropUrl ?? movie.imageUrl ?? '',
                    fit: BoxFit.cover,
                  ),
          ),
          // GRADIENTE DE FUSIÓN
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF141414),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // INFO Y BOTONES
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  movie.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bebasNeue(
                    color: Colors.white,
                    fontSize: 45,
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
        minimumSize: const Size(140, 40),
      ),
    );
  }

  // CORRECCIÓN DE NAVEGACIÓN SINCRONIZADA
  void _navigateToDetails(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => MovieDetailsScreen(
          movie: movie, // Se pasa el objeto Movie directamente
          user: widget.user,
        ),
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: list.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _navigateToDetails(list[i]),
              child: Container(
                width: 110,
                margin: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    list[i].imageUrl ?? '',
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
    _scrollController.dispose();
    _ytController?.dispose();
    super.dispose();
  }
}
