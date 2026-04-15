import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
  int _currentProviderIndex = 0;

  final List<Map<String, String>> _providers = [
    {"name": "Español (Omen)", "baseUrl": "https://vidsrc.win/embed/"},
    {"name": "VidSrc (.ru)", "baseUrl": "https://vsembed.ru/embed/"},
    {"name": "VidSrc (.su)", "baseUrl": "https://vsembed.su/embed/"},
  ];

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  // ESTE MÉTODO ES VITAL: Detecta cuando cambias de episodio/temporada desde afuera
  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.season != widget.season ||
        oldWidget.episode != widget.episode ||
        oldWidget.tmdbId != widget.tmdbId) {
      _initPlayer();
    }
  }

  void _initPlayer() {
    setState(() => _isLoading = true);
    _registerIFrame();

    // Pequeño delay para asegurar que el DOM registre la nueva factory
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _registerIFrame() {
    final String url = _generateUrl();
    final String contentId = widget.tmdbId ?? widget.imdbId ?? "unknown";

    // Incluimos temporada y episodio en el ID de la vista para forzar el refresco total
    final String viewType =
        'player-$contentId-S${widget.season}-E${widget.episode}-$_currentProviderIndex';

    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      iframe.setAttribute('referrerpolicy', 'origin');
      iframe.setAttribute(
        'allow',
        'autoplay; fullscreen; picture-in-picture; encrypted-media; storage-access',
      );

      return iframe;
    });
  }

  String _generateUrl() {
    final provider = _providers[_currentProviderIndex];
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');
    String id = widget.tmdbId ?? widget.imdbId ?? "";
    String mediaType = isTV ? "tv" : "movie";

    if (provider['name'] == "Español (Omen)") {
      String url = "${provider['baseUrl']}$mediaType?tmdb=$id";
      if (isTV) url += "&season=${widget.season}&episode=${widget.episode}";
      return "$url&server=omen&ds_lang=es";
    }

    return "${provider['baseUrl']}$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}";
  }

  @override
  Widget build(BuildContext context) {
    final String contentId = widget.tmdbId ?? widget.imdbId ?? "unknown";
    // La ViewType debe coincidir exactamente con la registrada en _registerIFrame
    final String currentViewType =
        'player-$contentId-S${widget.season}-E${widget.episode}-$_currentProviderIndex';

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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ActionChip(
              backgroundColor: Colors.redAccent,
              label: Text(
                _providers[_currentProviderIndex]['name']!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              onPressed: () {
                _currentProviderIndex =
                    (_currentProviderIndex + 1) % _providers.length;
                _initPlayer();
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ValueKey es CRÍTICO para que Flutter sepa que el widget cambió
          HtmlElementView(
            key: ValueKey(currentViewType),
            viewType: currentViewType,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),
        ],
      ),
    );
  }
}
