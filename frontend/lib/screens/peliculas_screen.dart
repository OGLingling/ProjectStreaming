import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'movie_details_screen.dart';

class PeliculasScreen extends StatefulWidget {
  final bool isActive;
  const PeliculasScreen({super.key, this.isActive = false});

  @override
  State<PeliculasScreen> createState() => _PeliculasScreenState();
}

class _PeliculasScreenState extends State<PeliculasScreen>
    with WidgetsBindingObserver {
  List<dynamic> moviesList = [];
  bool isLoading = true;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPageInView = false;

  final String movieBannerVideo =
      "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/TheBatman.mp4";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMovies();
    _initVideoBanner();
  }

  // --- LÓGICA DE DATOS ---
  Future<void> _loadMovies() async {
    try {
      // Intentamos traer contenido con etiqueta 'Pelicula' o 'Movie'
      final data = await ApiService.getMoviesByType('Pelicula');
      if (mounted) {
        setState(() {
          moviesList = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar películas: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void didUpdateWidget(PeliculasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive)
        _playVideo();
      else
        _pauseVideo();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    super.dispose();
  }

  void _pauseVideo() => _videoController?.pause();
  void _playVideo() {
    if (widget.isActive && _isPageInView && _isVideoInitialized) {
      _videoController?.play();
    }
  }

  void _initVideoBanner() {
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(movieBannerVideo))
          ..initialize().then((_) {
            if (mounted) {
              setState(() => _isVideoInitialized = true);
              _videoController?.setLooping(true);
              _videoController?.setVolume(1.0);
              _playVideo();
            }
          });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : VisibilityDetector(
              key: const Key('peliculas-screen-key'),
              onVisibilityChanged: (info) {
                _isPageInView = info.visibleFraction > 0.5;
                if (!_isPageInView)
                  _pauseVideo();
                else
                  _playVideo();
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildMovieBanner()),
                  _buildTitleSection("Películas para ti"),
                  _buildMovieGrid(),
                  const SliverToBoxAdapter(child: SizedBox(height: 50)),
                ],
              ),
            ),
    );
  }

  Widget _buildMovieBanner() {
    final double bannerHeight = MediaQuery.of(context).size.height * 0.75;
    return Stack(
      children: [
        Container(
          height: bannerHeight,
          width: double.infinity,
          color: Colors.black,
          child: _isVideoInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                ),
        ),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black26, Colors.transparent, Color(0xFF141414)],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 15,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "THE BATMAN",
                style: GoogleFonts.bebasNeue(
                  color: Colors.white,
                  fontSize: 70,
                  height: 0.9,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Acción • Crimen • Drama\nBatman explora la corrupción en Gotham mientras persigue al Acertijo.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  _HoverButton(
                    text: "Reproducir",
                    icon: Icons.play_arrow,
                    isPrimary: true,
                    onTap: () {},
                  ),
                  const SizedBox(width: 12),
                  _HoverButton(
                    text: "Información",
                    icon: Icons.info_outline,
                    isPrimary: false,
                    onTap: () {},
                  ),
                  const Spacer(),
                  _ageBadge("16+"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 15, top: 25, bottom: 15),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMovieGrid() {
    if (moviesList.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Text(
            "No se encontraron películas",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.68,
          crossAxisSpacing: 12,
          mainAxisSpacing: 15,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _MoviePosterCard(movie: moviesList[index]),
          childCount: moviesList.length,
        ),
      ),
    );
  }

  Widget _ageBadge(String age) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: const BoxDecoration(
        color: Colors.black45,
        border: Border(left: BorderSide(color: Colors.white, width: 3)),
      ),
      child: Text(
        age,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// --- WIDGET PARA BOTONES CON HOVER ---
class _HoverButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _HoverButton({
    required this.text,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isPrimary
                  ? (_isHovered ? Colors.white.withOpacity(0.8) : Colors.white)
                  : (_isHovered
                        ? Colors.white.withOpacity(0.4)
                        : Colors.white.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: widget.isPrimary ? Colors.black : Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.text,
                  style: TextStyle(
                    color: widget.isPrimary ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- WIDGET PARA POSTERS CON HOVER ---
class _MoviePosterCard extends StatefulWidget {
  final Map<String, dynamic> movie;
  const _MoviePosterCard({required this.movie});

  @override
  State<_MoviePosterCard> createState() => _MoviePosterCardState();
}

class _MoviePosterCardState extends State<_MoviePosterCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailsScreen(movieData: widget.movie),
            ),
          );
        },
        child: AnimatedScale(
          scale: _isHovered ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.movie['imageUrl'] ?? '',
                    fit: BoxFit.cover,
                  ),
                  if (_isHovered)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.2),
                        child: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
