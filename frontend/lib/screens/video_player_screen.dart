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

  // Eliminamos .win y priorizamos .pro para un reproductor limpio
  final List<Map<String, String>> _providers = [
    {"name": "Español (Pro)", "baseUrl": "https://vidsrc.pro/embed/"},
    {"name": "VidSrc (.ru)", "baseUrl": "https://vsembed.ru/embed/"},
    {"name": "VidSrc (.su)", "baseUrl": "https://vsembed.su/embed/"},
  ];

  @override
  void initState() {
    super.initState();
    _registerIFrame();
  }

  void _registerIFrame() {
    final String url = _generateUrl();
    final String contentId = widget.tmdbId ?? widget.imdbId ?? "unknown";

    // ViewType único para evitar que el audio de la serie anterior siga sonando
    final String viewType = 'player-$contentId-$_currentProviderIndex';

    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      // referrerpolicy="origin" es vital para que vidsrc.pro acepte la conexión
      iframe.setAttribute('referrerpolicy', 'origin');

      // Permisos para habilitar el selector de audio (Omen/Gekko) y pantalla completa
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
    String mediaType = isTV ? "tv" : "movie";

    // LÓGICA PARA VIDSRC.PRO CON AUDIO ESPAÑOL
    if (provider['name'] == "Español (Pro)") {
      // Formato: /embed/movie/ID o /embed/tv/ID/S/E
      String path = isTV
          ? "tv/$id/${widget.season}/${widget.episode}"
          : "movie/$id";

      // Intentamos forzar el servidor 'omen' (Español) directamente en la URL
      // ds_lang=es ayuda a la interfaz interna a elegir español
      return "${provider['baseUrl']}$path?server=omen&ds_lang=es";
    }

    // Formato estándar para los mirrors .ru y .su
    return "${provider['baseUrl']}$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}";
  }

  @override
  Widget build(BuildContext context) {
    final String contentId = widget.tmdbId ?? widget.imdbId ?? "unknown";
    final String currentViewType = 'player-$contentId-$_currentProviderIndex';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 13),
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
          // ValueKey asegura que el widget se destruya y reconstruya al cambiar de peli/serie
          HtmlElementView(
            key: ValueKey(currentViewType),
            viewType: currentViewType,
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
