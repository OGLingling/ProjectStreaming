import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/settings_provider.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String? tmdbId;
  final String? imdbId;
  final String title;
  final String type;
  final int season;
  final int episode;

  const VideoPlayerScreen({
    super.key,
    this.tmdbId,
    this.imdbId,
    required this.title,
    required this.type,
    this.season = 1,
    this.episode = 1,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isLoading = true;
  bool _isScraping = false;
  String? _errorMessage;
  VideoPlayerController? _videoPlayerController;

  // URLs base de tus APIs de scraping con redundancia
  final List<String> _apiBaseUrls = [
    'https://projectstreaming.onrender.com', // Servidor principal
    'https://moviewind-production.up.railway.app', // Servidor de respaldo
  ];

  // Lista de proveedores para scraping
  final List<Map<String, String>> _providers = [
    {"name": "VidSrc (.ru)", "baseUrl": "https://vsembed.ru/embed/"},
    {"name": "VidSrc (.su)", "baseUrl": "https://vsembed.su/embed/"},
  ];

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.season != widget.season ||
        oldWidget.episode != widget.episode ||
        oldWidget.tmdbId != widget.tmdbId) {
      _initPlayer();
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    if (_videoPlayerController != null) {
      await _videoPlayerController!.dispose();
    }

    setState(() {
      _isLoading = true;
      _isScraping = true;
      _errorMessage = null;
    });

    try {
      // Obtener URL del video mediante scraping
      final String targetUrl = _generateUrl();
      final String? videoUrl = await _fetchVideoUrl(targetUrl);

      if (videoUrl == null) {
        throw Exception('No se pudo obtener la URL del video');
      }

      // Configurar el controlador de video para HLS (.m3u8)
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
      );

      await _videoPlayerController!.initialize();
      await _videoPlayerController!.setLooping(true);
      await _videoPlayerController!.play();

      setState(() {
        _isLoading = false;
        _isScraping = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _isScraping = false;
        _errorMessage = error.toString();
      });

      _showErrorDialog(error.toString());
    }
  }

  Future<String?> _fetchVideoUrl(String targetUrl) async {
    Exception? lastError;

    // Intentar con cada servidor en orden (redundancia)
    for (final apiBaseUrl in _apiBaseUrls) {
      try {
        final String apiUrl =
            '$apiBaseUrl/api/extract?url=${Uri.encodeComponent(targetUrl)}';

        final response = await http
            .get(Uri.parse(apiUrl), headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['success'] == true) {
            return data['streamUrl'];
          } else {
            lastError = Exception(data['error'] ?? 'Error en el scraping');
            continue; // Intentar con el siguiente servidor
          }
        } else {
          lastError = Exception(
            'Error HTTP ${response.statusCode} en $apiBaseUrl',
          );
          continue; // Intentar con el siguiente servidor
        }
      } catch (error) {
        lastError = error is Exception ? error : Exception(error.toString());
        continue; // Intentar con el siguiente servidor
      }
    }

    // Si todos los servidores fallaron, lanzar el último error
    throw lastError ?? Exception('Todos los servidores fallaron');
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(
          'No se pudo cargar el video: ${error.contains('Timeout') ? 'El servidor tardó demasiado en responder' : error}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _generateUrl() {
    // Usar siempre el primer proveedor ya que la selección fue removida
    final provider = _providers[0];
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');
    String id = widget.tmdbId ?? widget.imdbId ?? "";
    String mediaType = isTV ? "tv" : "movie";

    // Lógica simplificada para los proveedores restantes
    return "${provider['baseUrl']}$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            if (widget.type.toLowerCase().contains('tv'))
              Text(
                "T${widget.season} • E${widget.episode}",
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
          ],
        ),
        actions: [
          if (_videoPlayerController != null && !_isLoading)
            IconButton(
              icon: Icon(
                _videoPlayerController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  if (_videoPlayerController!.value.isPlaying) {
                    _videoPlayerController!.pause();
                  } else {
                    _videoPlayerController!.play();
                  }
                });
              },
            ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return Stack(
            children: [
              // Video Player
              if (_videoPlayerController != null && !_isLoading)
                Center(
                  child: AspectRatio(
                    aspectRatio: _videoPlayerController!.value.aspectRatio,
                    child: VideoPlayer(_videoPlayerController!),
                  ),
                ),

              // Loading Indicator durante scraping
              if (_isScraping)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.redAccent),
                      SizedBox(height: 16),
                      Text(
                        'Obteniendo fuente de video (esto puede tardar unos segundos)...',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              // Loading Indicator general
              if (_isLoading && !_isScraping)
                const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                ),
              // --- CAPA DE SUBTÍTULOS (OVERLAY) ---
              if (settings.showSubtitles)
                Positioned(
                  bottom: 30, // Separación del borde inferior
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    // Para que los toques pasen al video (Play/Pause)
                    child: Container(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        // NOTA: Este es un texto simulado. En una implementación real con SRT/VTT,
                        // deberías parsear el archivo y actualizar este texto dinámicamente según el tiempo del video.
                        child: Text(
                          "Los subtítulos propios se mostrarán aquí...",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: settings.subtitleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(
                                offset: Offset(-1.5, -1.5),
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: Offset(1.5, -1.5),
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: Offset(1.5, 1.5),
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: Offset(-1.5, 1.5),
                                color: Colors.black,
                              ),
                              Shadow(blurRadius: 4.0, color: Colors.black),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
