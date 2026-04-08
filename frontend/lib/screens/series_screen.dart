import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../models/movie_model.dart';
import 'movie_details_screen.dart';

class SeriesScreen extends StatefulWidget {
  final bool isActive;
  const SeriesScreen({super.key, this.isActive = false});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen>
    with WidgetsBindingObserver {
  List<dynamic> seriesList = [];
  bool isLoading = true;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPageInView = false;

  // URL del trailer de "Estamos Muertos" (o la serie que prefieras)
  final String seriesBannerVideo =
      "https://zwgxgeoreechcwzizkbz.supabase.co/storage/v1/object/public/Trailers/EstamosMuertos.mp4";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSeries();
    _initVideoBanner();
  }

  @override
  void didUpdateWidget(SeriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Control de reproducción al cambiar de pestaña
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

  void _pauseVideo() {
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController?.pause();
    }
  }

  void _playVideo() {
    if (widget.isActive &&
        _isPageInView &&
        _isVideoInitialized &&
        _videoController != null) {
      if (!_videoController!.value.isPlaying) {
        _videoController?.play();
      }
    }
  }

  Future<void> _loadSeries() async {
    try {
      final data = await ApiService.getMoviesByType('Serie');
      if (mounted)
        setState(() {
          seriesList = data;
          isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _initVideoBanner() {
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(seriesBannerVideo))
          ..initialize().then((_) {
            if (mounted) {
              setState(() => _isVideoInitialized = true);
              _videoController?.setLooping(true);
              _videoController?.setVolume(1.0); // ACTIVAR SONIDO
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
              key: const Key('series-v-key'),
              onVisibilityChanged: (info) {
                _isPageInView = info.visibleFraction > 0.5;
                if (!_isPageInView)
                  _pauseVideo();
                else
                  _playVideo();
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildSeriesBanner()),
                  _buildTitleSection("Series Disponibles"),
                  _buildSeriesGrid(),
                  const SliverToBoxAdapter(child: SizedBox(height: 50)),
                ],
              ),
            ),
    );
  }

  Widget _buildSeriesBanner() {
    final double bannerHeight = MediaQuery.of(context).size.height * 0.8;
    return Stack(
      children: [
        // 1. Video de fondo
        Container(
          height: bannerHeight,
          width: double.infinity,
          color: Colors.black,
          child: _isVideoInitialized && _videoController != null
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
        // 2. Capa de degradado para que los textos resalten
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black45,
                  Colors.transparent,
                  const Color(0xFF141414),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // 3. Información y Botones (Interactivos)
        Positioned(
          bottom: 60,
          left: 20,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ESTAMOS MUERTOS",
                style: GoogleFonts.bebasNeue(
                  color: Colors.white,
                  fontSize: 70,
                  letterSpacing: 2,
                  height: 0.9,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Terror • Juvenil • Coreano\nUna escuela se convierte en la zona cero de un virus zombi.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  // BOTÓN REPRODUCIR
                  _bannerActionBtn("Reproducir", Icons.play_arrow, true, () {
                    debugPrint("Reproduciendo Serie...");
                    // Aquí podrías navegar a un reproductor de video
                  }),
                  const SizedBox(width: 12),
                  // BOTÓN INFORMACIÓN
                  _bannerActionBtn(
                    "Información",
                    Icons.info_outline,
                    false,
                    () {
                      debugPrint("Mostrando Información...");
                      // Puedes abrir un modal o navegar a detalles
                    },
                  ),
                  const Spacer(),
                  // Calificación de edad
                  _ageLabel("16+"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bannerActionBtn(
    String text,
    IconData icon,
    bool isPrimary,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: isPrimary ? Colors.white : Colors.grey.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.black : Colors.white,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: isPrimary ? Colors.black : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ageLabel(String age) {
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
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildTitleSection(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 30, 15, 15),
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

  Widget _buildSeriesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.68,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildSeriesCard(seriesList[index]),
          childCount: seriesList.length,
        ),
      ),
    );
  }

  Widget _buildSeriesCard(Map<String, dynamic> series) {
    return GestureDetector(
      onTap: () {
        _pauseVideo();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MovieDetailsScreen(movie: Movie.fromJson(series)),
          ),
        ).then((_) => _playVideo());
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          series['imageUrl'] ?? '',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Container(color: Colors.grey[900]),
        ),
      ),
    );
  }
}
