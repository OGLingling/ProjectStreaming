import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String? tmdbId; // Ahora opcional, pero recomendado
  final String? imdbId; // Mantenemos compatibilidad
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
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  int _currentProviderIndex = 0;

  // Configuración de proveedores con soporte para TMDB e IMDB
  final List<Map<String, String>> _providers = [
    {"name": "Vidsrc.me", "baseUrl": "https://vidsrc.me/embed/"},
    {"name": "Vidsrc.cc", "baseUrl": "https://vidsrc.cc/v2/embed/"},
    {"name": "Embed.su", "baseUrl": "https://embed.su/embed/"},
  ];

  WebUri _generateUrl() {
    final provider = _providers[_currentProviderIndex];
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');

    // Priorizamos TMDB ID si está disponible
    final String mediaType = isTV ? "tv" : "movie";
    final String idParam = widget.tmdbId != null
        ? "tmdb=${widget.tmdbId}"
        : "imdb=${widget.imdbId}";

    String url = "${provider['baseUrl']}$mediaType?$idParam";

    if (isTV) {
      url += "&s=${widget.season}&e=${widget.episode}";
    }

    return WebUri(url);
  }

  void _switchServer() {
    setState(() {
      _currentProviderIndex = (_currentProviderIndex + 1) % _providers.length;
      _isLoading = true;
    });
    _webViewController?.loadUrl(urlRequest: URLRequest(url: _generateUrl()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ActionChip(
              backgroundColor: Colors.redAccent,
              label: Text(
                _providers[_currentProviderIndex]['name']!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              onPressed: _switchServer,
              avatar: const Icon(Icons.dns, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: _generateUrl()),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowsInlineMediaPlayback: true,
              useOnLoadResource: true,
              // Bloqueo básico de Popups y optimización
              javaScriptCanOpenWindowsAutomatically: false,
              mediaPlaybackRequiresUserGesture: false,
              userAgent:
                  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            ),
            onWebViewCreated: (controller) => _webViewController = controller,
            onLoadStop: (controller, url) {
              setState(() => _isLoading = false);
            },
            // Seguridad: Bloqueamos cualquier intento de abrir una pestaña nueva (Publicidad)
            onCreateWindow: (controller, createWindowAction) async {
              return false;
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
    );
  }
}
