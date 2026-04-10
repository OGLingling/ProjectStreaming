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

  // Guardamos el viewType actual para que coincida exactamente en el registro y en la vista
  String _currentViewType = '';

  final List<Map<String, String>> _providers = [
    {"name": "Español (Pro)", "baseUrl": "https://vidsrc.pro/embed/"},
    {"name": "VidSrc (V2)", "baseUrl": "https://v2.vidsrc.me/embed/"},
    {"name": "VidSrc (Cloud)", "baseUrl": "https://vidsrc.cc/vapi/embed/"},
  ];

  @override
  void initState() {
    super.initState();
    _registerIFrame();
  }

  void _registerIFrame() {
    final String url = _generateUrl();
    final String contentId = widget.tmdbId ?? widget.imdbId ?? "unknown";

    // CORRECCIÓN: Generamos el ID una sola vez aquí
    _currentViewType =
        'player-$contentId-${DateTime.now().millisecondsSinceEpoch}';

    ui.platformViewRegistry.registerViewFactory(_currentViewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      // 'no-referrer' es vital para evitar el bloqueo de IP
      iframe.setAttribute('referrerpolicy', 'no-referrer');

      // Ajuste de Sandbox: 'allow-same-origin' es lo que quita la pantalla negra
      iframe.setAttribute(
        'sandbox',
        'allow-forms allow-pointer-lock allow-same-origin allow-scripts allow-top-navigation',
      );

      // Permisos para Omen/Gekko
      iframe.setAttribute(
        'allow',
        'autoplay; fullscreen; picture-in-picture; encrypted-media; storage-access',
      );

      return iframe;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  String _generateUrl() {
    final provider = _providers[_currentProviderIndex];
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');
    String id = widget.tmdbId ?? widget.imdbId ?? "";

    if (provider['name'] == "Español (Pro)") {
      String path = isTV
          ? "tv/$id/${widget.season}/${widget.episode}"
          : "movie/$id";
      // El servidor Omen es el que tiene el audio que buscas
      return "${provider['baseUrl']}$path?server=omen&ds_lang=es";
    }

    String mediaType = isTV ? "tv" : "movie";
    return "${provider['baseUrl']}$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ActionChip(
              backgroundColor: Colors.indigoAccent.withOpacity(0.8),
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
          // Usamos el _currentViewType que guardamos al registrar
          HtmlElementView(
            key: ValueKey(_currentViewType),
            viewType: _currentViewType,
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
