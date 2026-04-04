import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // 1. CONTROL DE SERVIDORES
  int _currentProviderIndex = 0;
  final List<String> _providers = ["Vidsrc", "Embed.su"];

  // 2. GENERADOR DE URL CON BACKUP
  WebUri _buildStreamingUrl() {
    final String id = widget.imdbId.trim();
    final bool isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');

    if (_currentProviderIndex == 0) {
      // OPCIÓN 1: VIDSRC
      return WebUri(
        isTV
            ? "https://vidsrc.me/embed/tv/$id/1/1"
            : "https://vidsrc.me/embed/movie/$id",
      );
    } else {
      // OPCIÓN 2: EMBED.SU (BACKUP)
      return WebUri(
        isTV
            ? "https://embed.su/embed/tv/$id/1/1"
            : "https://embed.su/embed/movie/$id",
      );
    }
  }

  // 3. FUNCIÓN PARA CAMBIAR DE SERVIDOR EN CALIENTE
  void _toggleServer() {
    setState(() {
      _currentProviderIndex = (_currentProviderIndex + 1) % _providers.length;
    });
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: _buildStreamingUrl()),
    );
    _startHideTimer(); // Reiniciar timer de controles
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startHideTimer();
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
      body: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
          if (_showControls) _startHideTimer();
        },
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: _buildStreamingUrl()),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowsInlineMediaPlayback: true,
                userAgent:
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                useShouldOverrideUrlLoading: true,
              ),
              onWebViewCreated: (controller) => _webViewController = controller,
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url.toString();
                // Permitimos vidsrc, embed.su y sus dominios de carga estática
                if (uri.contains("vidsrc") ||
                    uri.contains("embed.su") ||
                    uri.contains("vapi") ||
                    uri.contains("static")) {
                  return NavigationActionPolicy.ALLOW;
                }
                return NavigationActionPolicy
                    .CANCEL; // Bloquea Popups publicitarios
              },
            ),

            // CONTROLES SUPERIORES
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
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
                      Expanded(
                        child: Text(
                          "${widget.title} - ${_providers[_currentProviderIndex]}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // BOTÓN DE CAMBIAR SERVIDOR (BACKUP)
                      ElevatedButton.icon(
                        onPressed: _toggleServer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.8),
                        ),
                        icon: const Icon(
                          Icons.dns,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Cambiar Servidor",
                          style: TextStyle(color: Colors.white, fontSize: 12),
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

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _webViewController?.stopLoading();
    _hideTimer?.cancel();
    super.dispose();
  }
}
