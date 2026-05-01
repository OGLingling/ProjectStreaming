import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import '../providers/settings_provider.dart';
import 'web_player_widget.dart';

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
  bool _isSettingUpPlayer = false;
  String? _targetEmbedUrl;
  List<String> _candidateUrls = [];
  int _currentCandidateIndex = 0;
  Timer? _candidateTimer;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  final String _scraperBaseUrl = 'https://projectstreaming-1.onrender.com';

  String get _normalizedMediaType {
    final type = widget.type.toLowerCase();
    return type.contains('serie') || type.contains('tv') ? 'tv' : 'movie';
  }

  Map<String, String> get _streamHeaders {
    final embedOrigin = Uri.tryParse(_targetEmbedUrl ?? '')?.origin ?? 'https://vidsrc.me';
    return {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      'Referer': '$embedOrigin/',
      'Origin': embedOrigin,
      'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
    };
  }

  @override
  void initState() {
    super.initState();
    _startVideoDiscovery();
  }

  @override
  void dispose() {
    _candidateTimer?.cancel();
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

  Future<void> _startVideoDiscovery() async {
    if (!mounted) return;
    _candidateTimer?.cancel();
    await _disposeControllers();

    setState(() {
      _isLoading = true;
      _isScraping = true;
      _isSettingUpPlayer = false;
      _targetEmbedUrl = null;
      _candidateUrls = [];
      _currentCandidateIndex = 0;
    });

    try {
      final response = await http
          .get(
            Uri.parse('$_scraperBaseUrl/api/extract').replace(
              queryParameters: {
                'tmdbId': widget.tmdbId ?? widget.imdbId ?? '',
                'type': _normalizedMediaType,
                'season': widget.season.toString(),
                'episode': widget.episode.toString(),
              },
            ),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception("Error del servidor: ${response.statusCode}");
      }

      final data = json.decode(response.body);
      final candidates = data['data']?['candidates'];
      if (data['success'] == true && candidates is List && candidates.isNotEmpty) {
        _candidateUrls = candidates.map((item) => item.toString()).toList();
        _tryCandidate(0);
      } else {
        throw Exception("No se encontraron candidatos en el servidor");
      }
    } catch (e) {
      _handleError("Fallo al conectar con el motor: $e");
    }
  }

  Future<void> _setupRealPlayer(String realUrl) async {
    if (_videoPlayerController != null || _isSettingUpPlayer) return;

    _candidateTimer?.cancel();
    _isSettingUpPlayer = true;

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(realUrl),
        httpHeaders: _streamHeaders,
      );

      await _videoPlayerController!.initialize();

      if (!mounted) return;

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
            bufferedColor: Colors.white.withValues(alpha: 0.3),
          ),
        );
        _isLoading = false;
        _isScraping = false;
      });
    } catch (e) {
      _isSettingUpPlayer = false;
      await _disposeControllers();
      _tryNextCandidate("Stream rechazado por el servidor: $e");
    }
  }

  void _tryCandidate(int index) {
    if (!mounted) return;

    if (index >= _candidateUrls.length) {
      _handleError(
        "No se pudo sincronizar ningun servidor disponible para este contenido.",
      );
      return;
    }

    _candidateTimer?.cancel();
    setState(() {
      _currentCandidateIndex = index;
      _targetEmbedUrl = _candidateUrls[index];
      _isLoading = true;
      _isScraping = true;
      _isSettingUpPlayer = false;
    });

    _candidateTimer = Timer(const Duration(seconds: 18), () {
      _tryNextCandidate("Tiempo agotado en servidor ${index + 1}");
    });
  }

  void _tryNextCandidate(String reason) {
    debugPrint("Servidor descartado: $reason");
    _candidateTimer?.cancel();
    _tryCandidate(_currentCandidateIndex + 1);
  }

  void _handleError(String message) {
    if (mounted) {
      _candidateTimer?.cancel();
      setState(() {
        _isLoading = false;
        _isScraping = false;
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
              if (_isScraping && _targetEmbedUrl != null)
                WebPlayerWidget(
                  key: ValueKey(_targetEmbedUrl),
                  urlEmbed: _targetEmbedUrl!,
                  onVideoFound: (url) => _setupRealPlayer(url),
                  onLoadFailed: (error) => _tryNextCandidate(error),
                ),

              if (_chewieController != null && !_isLoading)
                Center(child: Chewie(controller: _chewieController!)),

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
                            : "Sincronizando servidor ${_currentCandidateIndex + 1}/${_candidateUrls.length}...",
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
