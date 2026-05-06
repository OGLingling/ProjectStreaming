import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
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

  String get _normalizedMediaType {
    final type = widget.type.toLowerCase();
    return type.contains('serie') || type.contains('tv') ? 'tv' : 'movie';
  }

  Map<String, String> get _streamHeaders {
    final embedOrigin =
        Uri.tryParse(_targetEmbedUrl ?? '')?.origin ?? 'https://vidsrc.me';
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
      final tmdbId = widget.tmdbId?.trim() ?? '';

      _candidateUrls = await ApiService.getExtractionCandidates(
        tmdbId: tmdbId,
        type: _normalizedMediaType,
        season: widget.season,
        episode: widget.episode,
      );
      _tryCandidate(0);
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
        final colorScheme = Theme.of(context).colorScheme;
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: true,
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: colorScheme.secondary,
            handleColor: colorScheme.secondary,
            backgroundColor: Colors.white24,
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
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          backgroundColor: const Color(0xFF1B1F22),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colorScheme.error.withValues(alpha: 0.45)),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.error),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Error de Carga',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            error,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startVideoDiscovery();
              },
              child: const Text('Reintentar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
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
                      CircularProgressIndicator(color: colorScheme.secondary),
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
