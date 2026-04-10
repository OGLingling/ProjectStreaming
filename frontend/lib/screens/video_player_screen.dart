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

  // Lista actualizada con los nuevos dominios oficiales
  final List<Map<String, String>> _providers = [
    {"name": "VidSrc (.ru)", "baseUrl": "https://vsembed.ru/embed/"},
    {"name": "VidSrc (.su)", "baseUrl": "https://vsembed.su/embed/"},
    {"name": "Vidsrc.pro", "baseUrl": "https://vidsrc.pro/embed/"},
    {"name": "Embed.su", "baseUrl": "https://embed.su/embed/"},
  ];

  @override
  void initState() {
    super.initState();
    _registerIFrame();
  }

  void _registerIFrame() {
    final String url = _generateUrl();
    // Usamos una clave única basada en el índice para forzar el refresco del iFrame
    final String viewType = 'video-player-view-$_currentProviderIndex';

    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      // CRÍTICO: referrerpolicy="origin" permite que el sitio cargue fuera de sandbox
      iframe.setAttribute('referrerpolicy', 'origin');
      // Permite el uso de almacenamiento local necesario para el reproductor
      iframe.setAttribute(
        'allow',
        'autoplay; fullscreen; picture-in-picture; encrypted-media; storage-access',
      );

      return iframe;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  String _generateUrl() {
    final provider = _providers[_currentProviderIndex];
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');
    String id = widget.tmdbId ?? widget.imdbId ?? "";
    String mediaType = isTV ? "tv" : "movie";

    // Formato de URL para los nuevos dominios vsembed
    if (provider['name']!.contains("VidSrc")) {
      return "${provider['baseUrl']}$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}";
    }

    return "${provider['baseUrl']}$mediaType/$id${isTV ? "/${widget.season}/${widget.episode}" : ""}";
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
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ActionChip(
              backgroundColor: Colors.indigoAccent,
              label: Text(
                _providers[_currentProviderIndex]['name']!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              onPressed: () {
                setState(() {
                  _currentProviderIndex =
                      (_currentProviderIndex + 1) % _providers.length;
                  _isLoading = true;
                });
                _registerIFrame();
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Usamos la vista dinámica para evitar que el iFrame anterior se quede pegado
          HtmlElementView(
            key: ValueKey('player-$_currentProviderIndex'),
            viewType: 'video-player-view-$_currentProviderIndex',
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.indigoAccent),
            ),
        ],
      ),
    );
  }
}
