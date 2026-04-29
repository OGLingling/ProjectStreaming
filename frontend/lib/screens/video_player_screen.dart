import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
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
  ChewieController? _chewieController;

  // Servidor de Render donde corre tu Scraper de Node.js
  final String _scraperBaseUrl = 'https://projectstreaming-1.onrender.com';

  // Lista de proveedores para el scraper
  final List<Map<String, String>> _providers = [
    {"name": "VidSrc (.ru)", "baseUrl": "https://vsembed.ru/embed/"},
    {"name": "VidSrc (.su)", "baseUrl": "https://vsembed.su/embed/"},
  ];

  int _currentProviderIndex = 0;
  int _scrapingAttempts = 0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _disposeControllers() async {
    _chewieController?.dispose();
    if (_videoPlayerController != null) {
      await _videoPlayerController!.dispose();
    }
    _videoPlayerController = null;
    _chewieController = null;
  }

  // Lógica principal de inicio
  Future<void> _initPlayer() async {
    await _disposeControllers();

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isScraping = true;
      _errorMessage = null;
      _scrapingAttempts = 0;
    });

    try {
      String? streamUrl;

      // Intentar obtener el link directo de los proveedores disponibles
      for (int i = 0; i < _providers.length; i++) {
        _currentProviderIndex = i;
        _scrapingAttempts++;

        final String targetUrl = _generateTargetUrl(i);

        try {
          streamUrl = await _fetchStreamFromScraper(targetUrl);
          if (streamUrl != null) break;
        } catch (e) {
          debugPrint('Error en proveedor ${_providers[i]['name']}: $e');
          if (i == _providers.length - 1) rethrow;
        }
      }

      if (streamUrl == null)
        throw Exception("No se obtuvo respuesta del servidor");

      // Inicializar VideoPlayer con el stream extraído (.m3u8 o .mp4)
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0 Safari/537.36',
        },
      );

      await _videoPlayerController!.initialize();

      // Configurar Chewie
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white.withOpacity(0.3),
        ),
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return const Center(
            child: Text(
              "Error de reproducción. Reintenta con otro servidor.",
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isScraping = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isScraping = false;
          _errorMessage = e.toString();
        });
        _showErrorDialog(e.toString());
      }
    }
  }

  // Comunicación con el backend de Node.js
  Future<String?> _fetchStreamFromScraper(String targetUrl) async {
    final String apiUrl =
        '$_scraperBaseUrl/api/extract?url=${Uri.encodeComponent(targetUrl)}';

    // Timeout de 55 segundos porque el scraper en Render tarda ~40s en navegar
    final response = await http
        .get(Uri.parse(apiUrl), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 55));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['streamUrl'] != null) {
        return data['streamUrl'];
      } else {
        throw Exception(data['error'] ?? "Error desconocido en el scraper");
      }
    } else {
      throw Exception(
        "Servidor caído o saturado (Código: ${response.statusCode})",
      );
    }
  }

  String _generateTargetUrl(int index) {
    final provider = _providers[index];
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');
    String id = widget.tmdbId ?? widget.imdbId ?? "";
    String mediaType = isTV ? "tv" : "movie";

    return "${provider['baseUrl']}$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}";
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(error, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _initPlayer();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
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
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
            if (widget.type.toLowerCase().contains('tv'))
              Text(
                "T${widget.season} • E${widget.episode}",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return Stack(
            children: [
              // Reproductor Chewie
              if (_chewieController != null && !_isLoading)
                Center(child: Chewie(controller: _chewieController!)),

              // Pantalla de carga informativa (Scraping)
              if (_isScraping)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.redAccent),
                      const SizedBox(height: 20),
                      Text(
                        "Buscando video en ${_providers[_currentProviderIndex]['name']}...",
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Text(
                        "Esto puede tardar hasta 1 minuto en Render Gratis",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              // Overlay de Subtítulos Personalizados
              if (settings.showSubtitles && !_isLoading)
                Positioned(
                  bottom: 50,
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          "Los subtítulos se configurarán aquí",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: settings.subtitleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
