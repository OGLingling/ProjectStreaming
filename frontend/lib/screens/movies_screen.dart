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
  bool _isMuted = true;

  final ScrollController _scrollController = ScrollController();

  // URL de tu API en Railway
  final String apiBaseUrl =
      "https://projectstreaming-production.up.railway.app/api/movies";
  // Tu API KEY de TMDB para los trailers
  final String tmdbApiKey = "TU_API_KEY_AQUI";

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  void _onScroll() {
    double offset = _scrollController.offset;
    // El header se vuelve opaco entre los 0 y 300px de scroll
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
          // Cargamos el trailer de la primera película para el Hero Banner
          if (movies.isNotEmpty) _loadTrailer(movies[0].id.toString());
        }
      }
    } catch (e) {
      debugPrint("Error loading movies: $e");
      if (mounted) setState(() => isLoading = false);
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      // Permite que el contenido se dibuje debajo de la barra de estado
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. CAPA DE CONTENIDO (Scroll)
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                )
              : MediaQuery.removePadding(
                  context: context,
                  removeTop: true, // ESTO ELIMINA LA ROTURA SUPERIOR
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
                      _buildSection(
                        "Recién añadidas",
                        movies.reversed.skip(2).toList(),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),

          // 2. HEADER FLOTANTE (Logo y Perfil)
          _buildNetflixHeader(),
        ],
      ),
    );
  }

  Widget _buildNetflixHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        // Se vuelve negro al hacer scroll
        color: Colors.black.withOpacity(_scrollOpacity.clamp(0.0, 0.9)),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  "MOVIEWIND",
                  style: GoogleFonts.bebasNeue(
                    color: Colors.red,
                    fontSize: 32,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 26),
                  onPressed: () {},
                ),
                const SizedBox(width: 5),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(Size size) {
    if (movies.isEmpty) return const SizedBox.shrink();
    final movie = movies[0];

    return SizedBox(
      height: size.height * 0.8,
      width: size.width,
      child: Stack(
        children: [
          // VIDEO DE FONDO
          Positioned.fill(
            child: _ytController != null
                ? IgnorePointer(
                    child: FittedBox(
                      fit: BoxFit.cover, // ELIMINA HUECOS NEGROS
                      child: SizedBox(
                        width: size.width,
                        height: size.height * 0.8,
                        child: YoutubePlayer(
                          controller: _ytController!,
                          showVideoProgressIndicator: false,
                        ),
                      ),
                    ),
                  )
                : Image.network(
                    movie.backdropUrl ?? movie.imageUrl ?? '',
                    fit: BoxFit.cover,
                  ),
          ),

          // GRADIENTE PARA FUSIÓN CON LA LISTA
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF141414), // Mismo que el Scaffold
                  ],
                  stops: const [0.0, 0.2, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // TÍTULO Y BOTONES
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
                    fontSize: 48,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 25),
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

          // BOTÓN DE MUTE
          Positioned(
            right: 20,
            bottom: 150,
            child: IconButton(
              icon: Icon(
                _isMuted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isMuted = !_isMuted;
                  _isMuted ? _ytController?.mute() : _ytController?.unMute();
                });
              },
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
      icon: Icon(icon, color: textCol, size: 24),
      label: Text(
        text,
        style: TextStyle(color: textCol, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        minimumSize: const Size(150, 40),
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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
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
