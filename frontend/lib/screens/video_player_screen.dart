import 'dart:async';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:video_player/video_player.dart';

import 'package:chewie/chewie.dart';

import '../providers/settings_provider.dart';

import '../services/api_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String? tmdbId;

  final String? imdbId;

  final String? directUrl;

  final String title;

  final String type;

  final int season;

  final int episode;

  const VideoPlayerScreen({
    super.key,

    this.tmdbId,

    this.imdbId,

    this.directUrl,

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
        Uri.tryParse(_targetEmbedUrl ?? '')?.origin ?? 'https://moviewind.app';

    return {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',

      'Referer': '$embedOrigin/',

      'Origin': embedOrigin,

      'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
    };
  }

  bool _isDirectStreamUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('googlevideo.com/videoplayback');
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

      _isSettingUpPlayer = false;

      _targetEmbedUrl = null;

      _candidateUrls = [];

      _currentCandidateIndex = 0;
    });

    try {
      final tmdbId = widget.tmdbId?.trim() ?? '';

      final directUrl = widget.directUrl?.trim();

      final candidates = <String>[
        if (directUrl != null && directUrl.isNotEmpty) directUrl,
      ];

      candidates.addAll(
        await ApiService.getExtractionCandidates(
          tmdbId: tmdbId,

          url: tmdbId.isEmpty ? directUrl : null,

          type: _normalizedMediaType,

          season: widget.season,

          episode: widget.episode,
        ),
      );

      _candidateUrls = candidates
          .where(_isDirectStreamUrl)
          .where((url) => !url.contains('/embed/'))
          .toSet()
          .toList();

      if (_candidateUrls.isEmpty) {
        _handleError(
          "No hay un stream directo disponible para este contenido. El backend debe entregar una URL .m3u8 o .mp4, no un embed del proveedor.",
        );
        return;
      }

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
      final proxiedUrl = await ApiService.createStreamSession(
        url: realUrl,
        sourceUrl: _targetEmbedUrl ?? realUrl,
        headers: _streamHeaders,
      );

      final playbackUrl = proxiedUrl ?? realUrl;

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(playbackUrl),

        httpHeaders: proxiedUrl == null ? _streamHeaders : const {},
      );

      await _videoPlayerController!.initialize().timeout(
        const Duration(seconds: 15),
      );

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

    final candidateUrl = _candidateUrls[index];
    final isDirectStream = _isDirectStreamUrl(candidateUrl);

    setState(() {
      _currentCandidateIndex = index;

      _targetEmbedUrl = candidateUrl;

      _isLoading = true;

      _isSettingUpPlayer = false;
    });

    if (isDirectStream) {
      _setupRealPlayer(candidateUrl);
      return;
    }

    _tryNextCandidate("Candidato no es un stream directo: $candidateUrl");
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
