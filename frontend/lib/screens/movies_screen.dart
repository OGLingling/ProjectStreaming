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
  double _scrollOpacity = 0.0;

  // Controladores de Video
  YoutubePlayerController? _ytController;
  String? _currentTrailerKey;
  bool _isMuted = true;

  final ScrollController _scrollController = ScrollController();
  final String tmdbApiKey = "TU_API_KEY_AQUI"; // REEMPLAZA CON TU KEY
  final String apiBaseUrl =
      "https://projectstreaming-production.up.railway.app/api/movies";

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  void _onScroll() {
    double offset = _scrollController.offset;
    double opacity = (offset / 300).clamp(0, 1.0);
    if (opacity != _scrollOpacity) {
      setState(() => _scrollOpacity = opacity);
    }
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
      debugPrint("Error loading movies: $e");
    }
  }

  // Lógica para obtener trailer real de TMDB
  Future<void> _loadTrailer(String movieId) async {
    final url =
        "https://api.themoviedb.org/3/movie/$movieId/videos?api_key=$tmdbApiKey&language=es-ES";
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List videos = data['results'];

        // Buscamos el trailer oficial de YouTube
        final trailer = videos.firstWhere(
          (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
          orElse: () => videos.isNotEmpty ? videos[0] : null,
        );

        if (trailer != null && mounted) {
          _initYoutube(trailer['key']);
        }
      }
    } catch (e) {
      debugPrint("TMDB Trailer Error: $e");
    }
  }

  void _initYoutube(String key) {
    _ytController?.dispose();
    setState(() {
      _currentTrailerKey = key;
      _ytController = YoutubePlayerController(
        initialVideoId: key,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: true,
          loop: true,
          hideControls: true,
          disableDragSeek: true,
          forceHD: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Stack(
        children: [
          // Contenido Principal
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                )
              : _buildMainContent(),

          // Header Estilo Netflix (Flotante)
          _buildNetflixHeader(),
        ],
      ),
    );
  }

  Widget _buildNetflixHeader() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 90,
      width: double.infinity,
      color: Colors.black.withOpacity(_scrollOpacity),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                "MOVIEWIND",
                style: GoogleFonts.bebasNeue(
                  color: Colors.red,
                  fontSize: 35,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 28),
                onPressed: () {},
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 30,
                  height: 30,
                  color: Colors.blue,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      children: [
        _buildHeroBanner(),
        const SizedBox(height: 20),
        _buildSection("Tendencias ahora", movies),
        _buildSection("Aclamadas por la crítica", movies.reversed.toList()),
        _buildSection("Recién añadidas", movies.reversed.skip(2).toList()),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildHeroBanner() {
    if (movies.isEmpty) return const SizedBox.shrink();
    final movie = movies[0];
    final size = MediaQuery.of(context).size;

    return SizedBox(
      height: size.height * 0.8,
      width: size.width,
      child: Stack(
        children: [
          // VIDEO O IMAGEN
          Positioned.fill(
            child: _ytController != null
                ? IgnorePointer(
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
                : Image.network(movie.backdropUrl ?? '', fit: BoxFit.cover),
          ),

          // GRADIENTE INFERIOR (Fusión perfecta)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black45,
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xFF141414),
                  ],
                  stops: [0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // INFO Y BOTONES
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  movie.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bebasNeue(
                    color: Colors.white,
                    fontSize: 55,
                    letterSpacing: 1.5,
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
                      Colors.white.withOpacity(0.3),
                      Colors.white,
                      movie,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // BOTÓN DE MUTE
          Positioned(
            right: 20,
            bottom: 120,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isMuted = !_isMuted;
                  _isMuted ? _ytController?.mute() : _ytController?.unMute();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
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
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => MovieDetailsScreen(movie: movie, user: widget.user),
          ),
        );
      },
      icon: Icon(icon, color: textCol, size: 28),
      label: Text(
        text,
        style: TextStyle(
          color: textCol,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        minimumSize: const Size(160, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        elevation: 0,
      ),
    );
  }

  Widget _buildSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) =>
                          MovieDetailsScreen(movie: list[i], user: widget.user),
                    ),
                  );
                },
                child: Container(
                  width: 115,
                  margin: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      list[i].imageUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
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
