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
  String _currentViewType = '';

  // Lista de proveedores corregida para evitar colisiones de rutas
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

    // CORRECCIÓN: ID único por cada carga para limpiar errores de IP previos
    _currentViewType =
        'player-$contentId-${DateTime.now().millisecondsSinceEpoch}';

    ui.platformViewRegistry.registerViewFactory(_currentViewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      // 'no-referrer' es vital para que vidsrc.pro no bloquee la petición
      iframe.setAttribute('referrerpolicy', 'no-referrer');

      // Sandbox ajustado para permitir que Omen/Gekko funcionen sin pantalla negra
      iframe.setAttribute(
        'sandbox',
        'allow-forms allow-pointer-lock allow-same-origin allow-scripts allow-top-navigation',
      );

      iframe.setAttribute(
        'allow',
        'autoplay; fullscreen; picture-in-picture; encrypted-media; storage-access',
      );

      return iframe;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  String _generateUrl() {
    final provider = _providers[_currentProviderIndex];
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');
    String id = widget.tmdbId ?? widget.imdbId ?? "";

    // 1. Lógica para VidSrc.pro (Usa rutas: /embed/type/id)
    if (provider['name'] == "Español (Pro)") {
      String path = isTV
          ? "tv/$id/${widget.season}/${widget.episode}"
          : "movie/$id";
      return "${provider['baseUrl']}$path?server=omen&ds_lang=es";
    }

    // 2. Lógica para VidSrc (V2) (Usa parámetros: ?tmdb=id)
    if (provider['name'] == "VidSrc (V2)") {
      String mediaType = isTV ? "tv" : "movie";
      String seasonEpi = isTV ? "&s=${widget.season}&e=${widget.episode}" : "";
      return "${provider['baseUrl']}$mediaType?tmdb=$id$seasonEpi";
    }

    // 3. Lógica para VidSrc (Cloud) (Usa parámetros: ?tmdb=id)
    if (provider['name'] == "VidSrc (Cloud)") {
      String mediaType = isTV ? "tv" : "movie";
      String seasonEpi = isTV
          ? "&season=${widget.season}&episode=${widget.episode}"
          : "";
      return "${provider['baseUrl']}$mediaType?tmdb=$id$seasonEpi";
    }

    return "";
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
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          // ValueKey asegura que Flutter destruya el iFrame viejo y cree uno nuevo
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
