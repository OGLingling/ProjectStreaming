import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/settings_provider.dart';
import 'web_player_widget.dart'; // Importamos nuestro pescador

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
  String? _targetEmbedUrl;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  final String _scraperBaseUrl = 'https://projectstreaming-1.onrender.com';

  @override
  void initState() {
    super.initState();
    _startVideoDiscovery();
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

  // Paso 1: Pedir a Render la lista de candidatos/embeds
  Future<void> _startVideoDiscovery() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isScraping = true;
      _errorMessage = null;
    });

    try {
      final String initialUrl = _generateTargetUrl();

      // Llamamos a tu API de Node.js para obtener el candidato ideal
      final response = await http
          .get(
            Uri.parse(
              '$_scraperBaseUrl/api/extract?url=${Uri.encodeComponent(initialUrl)}',
            ),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Usamos el primer candidato devuelto por tu servidor
        if (data['success'] == true && data['data']['candidates'].isNotEmpty) {
          setState(() {
            _targetEmbedUrl = data['data']['candidates'][0];
          });
        } else {
          throw Exception("No se encontraron candidatos en el servidor");
        }
      } else {
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      _handleError("Fallo al conectar con el motor: $e");
    }
  }

  // Paso 2: Inicializar Chewie con la URL real que pescó el WebView
  Future<void> _setupRealPlayer(String realUrl) async {
    if (_videoPlayerController != null) return;

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(realUrl),
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0 Safari/537.36',
          'Referer': 'https://vidsrc.me/',
        },
      );

      await _videoPlayerController!.initialize();

      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: true,
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.redAccent,
            handleColor: Colors.red,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.white.withOpacity(0.3),
          ),
        );
        _isLoading = false;
        _isScraping = false;
      });
    } catch (e) {
      _handleError("Error de reproducción: $e");
    }
  }

  String _generateTargetUrl() {
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');
    String id = widget.tmdbId ?? widget.imdbId ?? "";
    String mediaType = isTV ? "tv" : "movie";

    // Cambiamos el dominio a .me (que es más estable) y simplificamos la ruta
    // La estructura correcta es: https://vidsrc.me/embed/movie?tmdb=ID
    return "https://vidsrc.me/embed/$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}";
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isScraping = false;
        _errorMessage = message;
      });
      _showErrorDialog(message);
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Error de Carga',
          style: TextStyle(color: Colors.white),
        ),
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
              _startVideoDiscovery();
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
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return Stack(
            children: [
              // --- EL PESCADOR INVISIBLE ---
              if (_isScraping && _targetEmbedUrl != null)
                WebPlayerWidget(
                  urlEmbed: _targetEmbedUrl!,
                  onVideoFound: (url) => _setupRealPlayer(url),
                ),

              // --- REPRODUCTOR ---
              if (_chewieController != null && !_isLoading)
                Center(child: Chewie(controller: _chewieController!)),

              // --- CARGANDO ---
              if (_isLoading)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.redAccent),
                      const SizedBox(height: 20),
                      Text(
                        _targetEmbedUrl == null
                            ? "Obteniendo fuentes..."
                            : "Sincronizando video...",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
