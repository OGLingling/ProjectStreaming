import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/movie_model.dart';
import '../services/api_service.dart';

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
  YoutubePlayerController? _bannerController;

  @override
  void initState() {
    super.initState();
    _fetchMovies();
  }

  Future<void> _fetchMovies() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/movies'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            movies = data.map((m) => Movie.fromJson(m)).toList();
            isLoading = false;
          });
          _setupBannerVideo();
        }
      } else {
        _loadMockData();
      }
    } catch (e) {
      _loadMockData();
    }
  }

  void _loadMockData() {
    if (!mounted) return;
    final List<Movie> mockData = [
      Movie(
        title: "Dulce Hogar",
        // CORRECCIÓN: Usamos una URL de red como respaldo por si el asset falla
        imageUrl:
            "https://images.tmdb.org/t/p/original/69Sdb81InZna6nS876Y9999r7pG.jpg",
        category: "Terror / Horror.",
        description:
            "Tras una tragedia familiar, el solitario Cha Hyun-su se muda a un viejo complejo de apartamentos...",
        rating: 8.7,
        releaseDate: DateTime.now(),
        videoUrl: "https://www.youtube.com/watch?v=Uhvslx7urEw",
      ),
      Movie(
        title: "Avengers: Civil War",
        imageUrl:
            "https://images.tmdb.org/t/p/original/7WsyChvRStvS0kmORasySj9Sxc8.jpg",
        category: "Acción • Ciencia Ficción",
        description:
            "La presión política aumenta para instalar un sistema de responsabilidad...",
        rating: 7.8,
        releaseDate: DateTime.now(),
        videoUrl: "https://www.youtube.com/watch?v=s5PVmDAEuro",
      ),
    ];

    setState(() {
      movies = mockData;
      isLoading = false;
    });
    _setupBannerVideo();
  }

  void _setupBannerVideo() {
    if (movies.isNotEmpty && movies[0].videoUrl != null) {
      final videoId = YoutubePlayer.convertUrlToId(movies[0].videoUrl!);
      if (videoId != null) {
        _bannerController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: true,
            loop: true,
            hideControls: true,
            disableDragSeek: true,
          ),
        );
        if (mounted) setState(() {});
      }
    }
  }

  void _playVideo(String url) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenPlayer(videoId: videoId),
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
          : RefreshIndicator(
              onRefresh: _fetchMovies,
              color: Colors.red,
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  _buildBanner(),
                  _buildSection("Mi lista", movies),
                  _buildSection("Tendencias", movies.reversed.toList()),
                  _buildSection("Solo en MovieWind", movies),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildBanner() {
    if (movies.isEmpty) return const SizedBox(height: 400);

    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.75,
          width: double.infinity,
          color: Colors.black,
          child: _bannerController != null
              ? YoutubePlayer(
                  controller: _bannerController!,
                  showVideoProgressIndicator: false,
                  thumbnail: _movieImage(movies[0].imageUrl),
                )
              : _movieImage(movies[0].imageUrl),
        ),
        // Gradiente decorativo
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black45, Colors.transparent, Color(0xFF141414)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          left: 20, // Ajustado para móviles
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movies[0].title.toUpperCase(),
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 32, // Tamaño más realista para móviles
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  _btn(
                    Icons.play_arrow,
                    "Reproducir",
                    Colors.white,
                    Colors.black,
                    () => _playVideo(movies[0].videoUrl ?? ""),
                  ),
                  const SizedBox(width: 10),
                  _btn(
                    Icons.info_outline,
                    "Información",
                    Colors.grey[800]!.withOpacity(0.8),
                    Colors.white,
                    () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // MÉDORO CORREGIDO: Maneja errores de carga de imagen para que no quede en blanco
  Widget _movieImage(String url) {
    if (url.isEmpty) return Container(color: Colors.grey[900]);

    return Image(
      image:
          (url.startsWith('http') ? NetworkImage(url) : AssetImage(url))
              as ImageProvider,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        // Si la imagen falla (error de assets), muestra un fondo oscuro con un icono
        return Container(
          color: Colors.grey[900],
          child: const Center(
            child: Icon(Icons.movie, color: Colors.white24, size: 50),
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 25, bottom: 10),
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
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: list.length,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => _playVideo(list[index].videoUrl ?? ""),
              child: Container(
                width: 110, // Tamaño estilo poster vertical de Netflix
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _movieImage(list[index].imageUrl),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _btn(
    IconData icon,
    String label,
    Color bg,
    Color txt,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: txt, size: 24),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: txt,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class FullScreenPlayer extends StatefulWidget {
  final String videoId;
  const FullScreenPlayer({super.key, required this.videoId});

  @override
  State<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<FullScreenPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.red,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
