import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _showVideo = true;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  final String videoUrlSupabase =
      "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/DulceHogar.mp4";

  @override
  void initState() {
    super.initState();
    _loadData();
    _initVideoBanner();
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

  void _loadData() {
    // Ahora que tu modelo reconoce backdropUrl, podemos usarlos por separado
    movies = [
      Movie(
        title: "Dulce Hogar",
        imageUrl: "assets/Images/sweetHomeCartel.webp", // IMAGEN VERTICAL
        backdropUrl: "assets/Images/sweetHomeBanner.webp", // IMAGEN HORIZONTAL
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
        imageUrl: "assets/Images/civilWar.webp", // IMAGEN VERTICAL
        backdropUrl: "assets/Images/civilWarBanner.webp", // IMAGEN HORIZONTAL
        description: "El enfrentamiento entre Iron Man y Capitán América.",
        rating: 8.9,
        releaseDate: DateTime.now(),
        category: "Acción",
        videoUrl:
            "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/CivilWar.mp4",
      ),
      Movie(
        title: "Estamos Muertos",
        imageUrl: "assets/Images/EstamosMuertosCart.webp", // IMAGEN VERTICAL
        backdropUrl:
            "assets/Images/EstamosMuertosPost.webp", // IMAGEN HORIZONTAL
        description: "relleno relleno relleno relleno.......",
        rating: 8.9,
        releaseDate: DateTime.now(),
        category: "Acción",
        videoUrl:
            "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/estamos%20Muertos.mp4",
      ),
    ];
    setState(() => isLoading = false);
  }

  void _navigateToDetails(Movie movie) {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController?.pause();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(
          movieData: {
            'title': movie.title,
            'imageUrl': movie.imageUrl,
            'backdropUrl':
                movie.backdropUrl, // Se pasa el banner horizontal también
            'videoUrl': movie.videoUrl,
            'category': movie.category,
            'description': movie.description,
            'rating': movie.rating,
            'releaseDate': movie.releaseDate,
            'id': movie.title,
          },
        ),
      ),
    ).then((_) {
      if (_showVideo && _isVideoInitialized) {
        _videoController?.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildBanner(),
                const SizedBox(height: 20),
                _buildSection("Tu Próxima Historia", movies),
                const SizedBox(height: 50),
              ],
            ),
    );
  }

  Widget _buildBanner() {
    if (movies.isEmpty) return const SizedBox(height: 400);
    final double bannerHeight = MediaQuery.of(context).size.height * 0.8;

    // Aquí usamos específicamente el backdropUrl (horizontal)
    final String bannerImg = movies[0].backdropUrl ?? movies[0].imageUrl ?? '';

    return Stack(
      children: [
        Container(
          height: bannerHeight,
          width: double.infinity,
          color: Colors.black,
          child: _showVideo && _isVideoInitialized && _videoController != null
              ? FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                )
              : (bannerImg.startsWith('http')
                    ? Image.network(bannerImg, fit: BoxFit.cover)
                    : Image.asset(bannerImg, fit: BoxFit.cover)),
        ),
        // ... (resto del Stack: Gradientes y Textos)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
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
                movies[0].title.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 45,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    const Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 10,
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
                    Icons.play_arrow,
                    "Reproducir",
                    Colors.white,
                    Colors.black,
                    () {
                      _navigateToDetails(movies[0]);
                    },
                  ),
                  const SizedBox(width: 15),
                  _btnAction(
                    Icons.info_outline,
                    "Más información",
                    Colors.white.withOpacity(0.3),
                    Colors.white,
                    () {
                      _navigateToDetails(movies[0]);
                    },
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
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: list.length,
            itemBuilder: (context, index) {
              // Para la lista usamos imageUrl (Poster Vertical)
              final String posterImg = list[index].imageUrl ?? '';
              return GestureDetector(
                onTap: () => _navigateToDetails(list[index]),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  child: Hero(
                    tag: list[index].title,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: posterImg.startsWith('http')
                          ? Image.network(posterImg, fit: BoxFit.cover)
                          : Image.asset(posterImg, fit: BoxFit.cover),
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

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }
}
