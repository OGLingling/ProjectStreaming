import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  int _currentProviderIndex = 0;

  // Tu proxy sigue siendo útil para ciertos servidores, pero lo usaremos de forma selectiva
  final String _proxyBaseUrl =
      "https://projectstreaming-production.up.railway.app/api/proxy-stream?url=";

  final List<Map<String, String>> _providers = [
    {"name": "Vidsrc.ru (Directo)", "baseUrl": "https://vidsrcme.ru/embed/"},
    {"name": "Vidsrc.pro", "baseUrl": "https://vidsrc.pro/embed/"},
    {"name": "Embed.su", "baseUrl": "https://embed.su/embed/"},
    {"name": "VidLink", "baseUrl": "https://vidlink.pro/"},
  ];

  WebUri _generateUrl() {
    final provider = _providers[_currentProviderIndex];
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');
    String id = widget.tmdbId ?? widget.imdbId ?? "";
    String mediaType = isTV ? "tv" : "movie";

    String rawUrl = "";

    // Lógica específica para Vidsrc.ru que encontraste
    if (provider['name']!.contains("Vidsrc.ru")) {
      rawUrl =
          "${provider['baseUrl']}$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}";
      // Para este servidor probaremos carga DIRECTA sin proxy para evitar errores 500
      return WebUri(rawUrl);
    }

    // Para los demás, seguimos usando el proxy de Railway
    if (provider['name'] == "Vidsrc.me" || provider['name'] == "Vidsrc.pro") {
      rawUrl =
          "${provider['baseUrl']}$mediaType/$id${isTV ? "/${widget.season}/${widget.episode}" : ""}";
    } else {
      rawUrl =
          "${provider['baseUrl']}$mediaType/$id${isTV ? "/${widget.season}/${widget.episode}" : ""}";
    }

    return WebUri("$_proxyBaseUrl${Uri.encodeComponent(rawUrl)}");
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
                _webViewController?.loadUrl(
                  urlRequest: URLRequest(
                    url: _generateUrl(),
                    // Inyectamos el origen para que el reproductor no pida desactivar Sandbox
                    headers: {'Referer': 'https://vidsrcme.ru/'},
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: _generateUrl(),
              headers: {'Referer': 'https://vidsrcme.ru/'},
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowsInlineMediaPlayback: true,
              // Usamos un UserAgent de Smart TV para que los scripts de protección sean menos agresivos
              userAgent:
                  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",

              // Configuraciones para saltar bloqueos de CORS
              allowUniversalAccessFromFileURLs: true,
              allowFileAccessFromFileURLs: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,

              // Deshabilitar protecciones de navegación que bloquean el iFrame
              safeBrowsingEnabled: false,
              isInspectable: true,
            ),
            onWebViewCreated: (controller) => _webViewController = controller,
            onLoadStop: (controller, url) => setState(() => _isLoading = false),
            // Importante: No permitir popups que rompan el flujo del video
            onCreateWindow: (controller, createWindowAction) async => false,
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
