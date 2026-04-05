import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String imdbId;
  final String title;
  final String type;

  const VideoPlayerScreen({
    super.key,
    required this.imdbId,
    required this.title,
    required this.type,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _showControls = true;
  Timer? _hideTimer;
  InAppWebViewController? _webViewController;

  // CONTROL DE SERVIDORES
  int _currentProviderIndex = 0;
  final List<String> _providers = ["Vidsrc.me", "Embed.su"];

  // GENERADOR DE URL (WEB OPTIMIZED)
  WebUri _buildStreamingUrl() {
    final String id = widget.imdbId.trim();
    final bool isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');

    if (_currentProviderIndex == 0) {
      // Servidor 1: Vidsrc
      return WebUri(
        isTV
            ? "https://vidsrc.me/embed/tv/$id/1/1"
            : "https://vidsrc.me/embed/movie/$id",
      );
    } else {
      // Servidor 2: Embed.su (Backup)
      return WebUri(
        isTV
            ? "https://embed.su/embed/tv/$id/1/1"
            : "https://embed.su/embed/movie/$id",
      );
    }
  }

  void _toggleServer() {
    setState(() {
      _currentProviderIndex = (_currentProviderIndex + 1) % _providers.length;
    });
    // En Web, recargamos la URL directamente en el controlador
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: _buildStreamingUrl()),
    );
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        // En Web usamos MouseRegion para detectar movimiento del ratón
        onHover: (_) {
          if (!_showControls) setState(() => _showControls = true);
          _startHideTimer();
        },
        child: Stack(
          children: [
            // WEBVIEW OPTIMIZADO PARA NAVEGADORES
            InAppWebView(
              initialUrlRequest: URLRequest(url: _buildStreamingUrl()),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowsInlineMediaPlayback: true,
                // En Web, el UserAgent del navegador suele ser suficiente,
                // pero lo forzamos para evitar bloqueos de frames.
                userAgent:
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
              ),
              onWebViewCreated: (controller) => _webViewController = controller,
            ),

            // CONTROLES
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${widget.title} (${_providers[_currentProviderIndex]})",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // BOTÓN DE BACKUP
                      TextButton.icon(
                        onPressed: _toggleServer,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.7),
                        ),
                        icon: const Icon(Icons.swap_calls, color: Colors.white),
                        label: const Text(
                          "Cambiar de Servidor",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
