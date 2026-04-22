import 'dart:ui_web' as ui;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import '../providers/settings_provider.dart';

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
  String?
  _extractedStreamUrl; // Almacenará el enlace .m3u8 si el scraper tiene éxito

  // Lista actualizada: VidSrc (.ru) ahora es el principal
  final List<Map<String, String>> _providers = [
    {"name": "VidSrc (.ru)", "baseUrl": "https://vsembed.ru/embed/"},
    {"name": "VidSrc (.su)", "baseUrl": "https://vsembed.su/embed/"},
  ];

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.season != widget.season ||
        oldWidget.episode != widget.episode ||
        oldWidget.tmdbId != widget.tmdbId) {
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    setState(() => _isLoading = true);

    // 1. Construir la URL base de Vidsrc
    final String targetUrl = _generateUrl();

    // 2. Intentar extraer el .m3u8 usando nuestro backend
    await _extractDirectStream(targetUrl);

    // 3. Registrar el iframe de todas formas. Si tenemos el .m3u8, aquí lo ideal
    // sería usar video_player nativo. Pero por ahora inyectamos el src.
    _registerIFrame();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _extractDirectStream(String targetUrl) async {
    try {
      debugPrint("🟡 Iniciando extracción para URL: $targetUrl");
      // Importante: Usar la URL de tu backend en producción
      final Uri apiEndpoint = Uri.parse(
        'https://projectstreaming-production.up.railway.app/api/extract?url=${Uri.encodeComponent(targetUrl)}',
      );

      final response = await http.get(apiEndpoint);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['streamUrl'] != null) {
          _extractedStreamUrl = data['streamUrl'];
          debugPrint("🟢 Recibiendo m3u8 del servidor: $_extractedStreamUrl");
        }
      } else {
        debugPrint("🔴 Error en scraper: Código ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("🔴 Excepción al contactar scraper: $e");
    }
  }

  void _registerIFrame() {
    // Si tenemos el link directo extraído, lo usamos. Si no, caemos en el iframe original.
    final String urlToPlay = _extractedStreamUrl ?? _generateUrl();
    final String contentId = widget.tmdbId ?? widget.imdbId ?? "unknown";

    final String viewType =
        'player-$contentId-S${widget.season}-E${widget.episode}-$_currentProviderIndex';

    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = urlToPlay
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

    // Lógica simplificada para los proveedores restantes
    return "${provider['baseUrl']}$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}";
  }

  @override
  Widget build(BuildContext context) {
    final String contentId = widget.tmdbId ?? widget.imdbId ?? "unknown";
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
                setState(() {
                  _currentProviderIndex =
                      (_currentProviderIndex + 1) % _providers.length;
                  _initPlayer();
                });
              },
            ),
          ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return Stack(
            children: [
              HtmlElementView(
                key: ValueKey(currentViewType),
                viewType: currentViewType,
              ),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                ),
              // --- CAPA DE SUBTÍTULOS (OVERLAY) ---
              if (settings.showSubtitles)
                Positioned(
                  bottom: 30, // Separación del borde inferior
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    // Para que los toques pasen al video (Play/Pause)
                    child: Container(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        // NOTA: Este es un texto simulado. En una implementación real con SRT/VTT,
                        // deberías parsear el archivo y actualizar este texto dinámicamente según el tiempo del video.
                        child: Text(
                          "Los subtítulos propios se mostrarán aquí...",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: settings.subtitleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(
                                offset: Offset(-1.5, -1.5),
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: Offset(1.5, -1.5),
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: Offset(1.5, 1.5),
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: Offset(-1.5, 1.5),
                                color: Colors.black,
                              ),
                              Shadow(blurRadius: 4.0, color: Colors.black),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
