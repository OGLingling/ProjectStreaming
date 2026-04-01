import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/movie_model.dart';
import 'movie_details_screen.dart';

class MoviesScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const MoviesScreen({super.key, this.user});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen>
    with WidgetsBindingObserver {
  List<Movie> movies = [];
  bool isLoading = true;
  bool _showVideo = true;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // Cambia esto por tu URL de Railway
  final String apiBaseUrl = "https://tu-proyecto.railway.app/api/movies";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
          if (movies.isNotEmpty) _initVideoBanner();
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _initVideoBanner() {
    // Usamos el videoUrl de la primera película o uno por defecto
    String? url =
        movies[0].videoUrl ??
        "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/DulceHogar.mp4";

    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isVideoInitialized = true);
          _videoController?.setVolume(0.0); // Banner silencioso es mejor
          _videoController?.play();
          _videoController?.setLooping(true);
        }
      });
  }

  void _navigateToDetails(Map<String, dynamic> movieData) async {
    _videoController?.pause();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movieData: movieData),
      ),
    );
    if (mounted && _showVideo && _isVideoInitialized) _videoController?.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : movies.isEmpty
          ? const Center(
              child: Text(
                "No hay películas",
                style: TextStyle(color: Colors.white),
              ),
            )
          : VisibilityDetector(
              key: const Key('movies-main-key'),
              onVisibilityChanged: (info) {
                if (info.visibleFraction > 0.8)
                  _videoController?.play();
                else
                  _videoController?.pause();
              },
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildBanner(),
                  const SizedBox(height: 20),
                  _buildSection("Tu Próxima Historia", movies),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildBanner() {
    final Movie mainMovie = movies[0];
    final String bannerImg = (mainMovie.backdropUrl ?? '').trim();

    return Stack(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          width: double.infinity,
          child: _showVideo && _isVideoInitialized
              ? VideoPlayer(_videoController!)
              : Image.network(bannerImg, fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, const Color(0xFF141414)],
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
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _navigateToDetails(mainMovie.toJson()),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Reproducir"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _navigateToDetails(list[i].toJson()),
              child: Container(
                width: 130,
                margin: const EdgeInsets.only(left: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
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
    _videoController?.dispose();
    super.dispose();
  }
}
