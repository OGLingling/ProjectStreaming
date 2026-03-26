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

  final String videoUrlSupabase =
      "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/DulceHogar.mp4";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _initVideoBanner();
  }

  @override
  void deactivate() {
    _videoController?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_videoController == null || !_isVideoInitialized) return;
    if (state == AppLifecycleState.paused) {
      _videoController?.pause();
    }
  }

  void _initVideoBanner() {
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(videoUrlSupabase))
          ..initialize().then((_) {
            if (mounted) {
              setState(() => _isVideoInitialized = true);
              _videoController?.setLooping(false);
              _videoController?.setVolume(1.0);
              _videoController?.play();

              _videoController?.addListener(() {
                if (_videoController!.value.position >=
                    _videoController!.value.duration) {
                  if (_showVideo) setState(() => _showVideo = false);
                }
              });
            }
          });
  }

  // Corregido: Ahora recibe los datos directamente como Map
  void _navigateToDetails(Map<String, dynamic> movieData) async {
    _videoController?.pause();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movieData: movieData),
      ),
    );
    if (mounted && _showVideo && _isVideoInitialized) {
      _videoController?.play();
    }
  }

  void _loadData() {
    movies = [
      Movie(
        title: "Dulce Hogar",
        imageUrl: "assets/Images/sweetHomeCartel.webp",
        backdropUrl: "assets/Images/sweetHomeBanner.webp",
        description:
            "Tras una tragedia familiar, el solitario Cha Hyun-su se muda...",
        rating: 8.7,
        releaseDate: DateTime.now(),
        category: "Terror / Horror",
        videoUrl:
            "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/DulceHogar.mp4",
      ),
      Movie(
        title: "Avengers: Civil War",
        imageUrl: "assets/Images/civilWar.webp",
        backdropUrl: "assets/Images/civilWarBanner.webp",
        description: "El enfrentamiento entre Iron Man y Capitán América.",
        rating: 8.2,
        releaseDate: DateTime.now(),
        category: "Acción",
        videoUrl:
            "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/CivilWar.mp4",
      ),
      Movie(
        title: "Estamos Muertos",
        imageUrl: "assets/Images/EstamosMuertosCart.webp",
        backdropUrl: "assets/Images/EstamosMuertosPost.webp",
        description: "Virus zombi en un instituto.",
        rating: 8.5,
        releaseDate: DateTime.now(),
        category: "Terror / Horror",
        videoUrl:
            "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/EstamosMuertos.mp4",
      ),
      Movie(
        title: "The Batman",
        imageUrl: "assets/Images/TheBatmanCart.webp",
        backdropUrl: "assets/Images/TheBatmanPost.webp",
        description: "Batman descubre la corrupción en Gotham City.",
        rating: 8.5,
        releaseDate: DateTime.now(),
        category: "Suspenso",
        videoUrl:
            "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/TheBatman.mp4",
      ),
      Movie(
        title: "Stranger Things",
        imageUrl: "assets/Images/StrangerThingsCart.webp",
        backdropUrl: "assets/Images/StrangerThingsPost.webp",
        description: "Un misterio que involucra experimentos secretos.",
        rating: 8.5,
        releaseDate: DateTime.now(),
        category: "Terror / Horror",
        videoUrl:
            "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/stranger%20Things.mp4",
      ),
    ];
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : VisibilityDetector(
              key: const Key('movies-main-unique-key'),
              onVisibilityChanged: (info) {
                if (!mounted ||
                    _videoController == null ||
                    !_isVideoInitialized)
                  return;
                if (info.visibleFraction > 0.9) {
                  if (_showVideo) _videoController?.play();
                } else {
                  _videoController?.pause();
                }
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
    if (movies.isEmpty) return const SizedBox(height: 400);
    final double bannerHeight = MediaQuery.of(context).size.height * 0.8;
    final Movie mainMovie = movies[0];
    final String bannerImg = (mainMovie.backdropUrl ?? mainMovie.imageUrl ?? '').trim();
    final bool hasValidBannerImg =
        bannerImg.isNotEmpty && bannerImg.toLowerCase() != 'null';

    return Stack(
      children: [
        Container(
          height: bannerHeight,
          width: double.infinity,
          color: Colors.black,
          child: _showVideo && _isVideoInitialized && _videoController != null
              ? FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                )
              : (!hasValidBannerImg
                    ? const SizedBox.expand()
                    : (bannerImg.startsWith('http')
                        ? Image.network(
                            bannerImg,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          )
                        : (bannerImg.startsWith('assets/')
                            ? Image.asset(
                                bannerImg,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              )
                            : const SizedBox.expand()))),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                  Colors.transparent,
                  const Color(0xFF141414),
                ],
                stops: const [0.0, 0.2, 0.7, 1.0],
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
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    const Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 15,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _btnAction(
                    Icons.play_arrow_rounded,
                    "Reproducir",
                    Colors.white,
                    Colors.black,
                    () => _navigateToDetails(mainMovie.toJson()),
                  ),
                  const SizedBox(width: 15),
                  _btnAction(
                    Icons.info_outline_rounded,
                    "Más información",
                    Colors.white.withOpacity(0.2),
                    Colors.white,
                    () => _navigateToDetails(mainMovie.toJson()),
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
          padding: const EdgeInsets.only(left: 20, top: 10, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SChildList(list: list, onSelect: (data) => _navigateToDetails(data)),
      ],
    );
  }

  Widget _btnAction(
    IconData icon,
    String label,
    Color bg,
    Color txt,
    VoidCallback onTap,
  ) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: txt, size: 28),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: txt,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SChildList extends StatelessWidget {
  final List<Movie> list;
  final Function(Map<String, dynamic>) onSelect;
  const SChildList({super.key, required this.list, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final movie = list[index];
          final img = (movie.imageUrl ?? '').trim();
          final hasValidImg = img.isNotEmpty && img.toLowerCase() != 'null';
          return GestureDetector(
            onTap: () => onSelect(movie.toJson()),
            child: Container(
              width: 120,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Hero(
                tag: movie.title,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: !hasValidImg
                      ? Container(color: Colors.black)
                      : (img.startsWith('http')
                          ? Image.network(img, fit: BoxFit.cover)
                          : (img.startsWith('assets/')
                              ? Image.asset(img, fit: BoxFit.cover)
                              : Container(color: Colors.black))),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
