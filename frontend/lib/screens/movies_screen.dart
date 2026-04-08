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

class _MoviesScreenState extends State<MoviesScreen>
    with WidgetsBindingObserver {
  List<Movie> movies = [];
  bool isLoading = true;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isMuted = true;
  double _scrollOffset = 0.0;
  final ScrollController _scrollController = ScrollController();

  final String apiBaseUrl =
      "https://projectstreaming-production.up.railway.app/api/movies";

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
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
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _initVideoBanner() {
    // URL por defecto para el trailer de MOVIEWIND
    String url =
        "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/DulceHogar.mp4";

    _videoController = VideoPlayerController.networkUrl(WebUri(url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isVideoInitialized = true);
          _videoController?.setVolume(0.0);
          _videoController?.play();
          _videoController?.setLooping(true);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size(MediaQuery.of(context).size.width, 70),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: Colors.black.withOpacity((_scrollOffset / 350).clamp(0, 0.9)),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    "MOVIEWIND",
                    style: GoogleFonts.bebasNeue(
                      color: Colors.red,
                      fontSize: 32,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.search, color: Colors.white, size: 28),
                  const SizedBox(width: 20),
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : VisibilityDetector(
              key: const Key('movies-main-key'),
              onVisibilityChanged: (info) {
                if (info.visibleFraction > 0.5)
                  _videoController?.play();
                else
                  _videoController?.pause();
              },
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  _buildVideoBanner(),
                  const SizedBox(height: 10),
                  _buildSection("Tendencias ahora", movies),
                  _buildSection(
                    "Aclamadas por la crítica",
                    movies.reversed.toList(),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildVideoBanner() {
    if (movies.isEmpty) return const SizedBox.shrink();
    final mainMovie = movies[0];

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Stack(
        children: [
          // Capa de Video o Imagen de respaldo
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
                : Image.network(mainMovie.backdropUrl ?? '', fit: BoxFit.cover),
          ),
          // Gradiente Inferior Negro (Fusión con el feed)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black38,
                    Colors.transparent,
                    Color(0xFF141414),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          // Controles y Texto
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  mainMovie.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bebasNeue(
                    color: Colors.white,
                    fontSize: 48,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MovieDetailsScreen(movieData: mainMovie.toJson()),
                        ),
                      ),
                      icon: const Icon(
                        Icons.play_arrow,
                        size: 30,
                        color: Colors.black,
                      ),
                      label: const Text(
                        "Reproducir",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        minimumSize: const Size(140, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.info_outline,
                        size: 26,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Información",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        minimumSize: const Size(140, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Botón de Mute (Esquina inferior derecha del banner)
          Positioned(
            bottom: 70,
            right: 20,
            child: IconButton(
              icon: Icon(
                _isMuted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () {
                setState(() {
                  _isMuted = !_isMuted;
                  _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
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
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: list.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MovieDetailsScreen(movieData: list[i].toJson()),
                ),
              ),
              child: Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
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
        ),
      ],
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
