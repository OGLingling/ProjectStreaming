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

  // Lista de proveedores optimizada para evitar errores de IP y bloqueos
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

    // ID único para limpiar la instancia previa y evitar solapamiento de audio
    final String viewType = 'player-${DateTime.now().millisecondsSinceEpoch}';

    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      // CAMBIO CLAVE: Usamos 'no-referrer' para que el servidor no bloquee la IP de origen
      iframe.setAttribute('referrerpolicy', 'no-referrer');

      // SANDBOX: Permite scripts y carga, pero bloquea popups de "Actualización de Flash"
      iframe.setAttribute(
        'sandbox',
        'allow-forms allow-pointer-lock allow-same-origin allow-scripts allow-top-navigation',
      );

      // Habilita el acceso al almacenamiento para que el reproductor guarde tu progreso
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

    // Formato específico para VidSrc.pro (Audio Español: Omen/Gekko)
    if (provider['name'] == "Español (Pro)") {
      String path = isTV
          ? "tv/$id/${widget.season}/${widget.episode}"
          : "movie/$id";
      return "${provider['baseUrl']}$path?server=omen&ds_lang=es";
    }

    // Formato API para mirrors alternativos
    String mediaType = isTV ? "tv" : "movie";
    return "${provider['baseUrl']}$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}";
  }

  @override
  Widget build(BuildContext context) {
    // Generamos un Key basado en el proveedor para forzar el refresco del widget
    final String playerKey = 'view-${widget.tmdbId}-$_currentProviderIndex';
    final String viewType = ui.platformViewRegistry
        .toString(); // Referencia al factory registrado

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
              side: BorderSide.none,
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
          // Usamos un Key dinámico para asegurar que Flutter recree el iFrame al cambiar de servidor
          HtmlElementView(
            key: UniqueKey(),
            viewType:
                'player-${DateTime.now().millisecondsSinceEpoch}', // Debe coincidir con el registrado arriba
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
