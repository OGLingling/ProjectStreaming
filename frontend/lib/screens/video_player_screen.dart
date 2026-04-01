import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String imdbId;
  final String title;
  final String type; // <--- 1. AGREGADO AQUÍ

  const VideoPlayerScreen({
    super.key,
    required this.imdbId,
    required this.title,
    required this.type, // <--- 2. REQUERIDO AQUÍ
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _showControls = true;
  Timer? _hideTimer;
  InAppWebViewController? _webViewController;

  // 3. LA FUNCIÓN DEBE ESTAR AQUÍ ADENTRO PARA USAR "widget."
  WebUri _getVidsrcUrl() {
    final String id = widget.imdbId.trim();

    // Limpiamos el type y manejamos posibles valores nulos
    final String rawType = (widget.type ?? "").toLowerCase();

    // Verificamos si es serie (incluyendo variaciones comunes)
    final bool isSerie = rawType.contains('serie') || rawType.contains('tv');

    final String finalUrl;
    if (isSerie) {
      finalUrl = "https://vidsrc.to/embed/tv/$id/1/1";
    } else {
      finalUrl = "https://vidsrc.to/embed/movie/$id";
    }

    // ESTO ES VITAL: Mira la consola de depuración cuando des clic en reproducir
    print("DEBUG_VIDEO_URL: $finalUrl");

    return WebUri(finalUrl);
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
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: _getVidsrcUrl()),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowsInlineMediaPlayback: true,
                mediaPlaybackRequiresUserGesture: false,
                transparentBackground: true,
                // Permite que el control de navegación funcione
                useShouldOverrideUrlLoading: true,
                javaScriptCanOpenWindowsAutomatically: false,
                userAgent:
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              // EL NOMBRE CORRECTO ES ESTE:
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                var uri = navigationAction.request.url.toString();

                // Permitimos TODO lo que tenga que ver con vidsrc o el reproductor de video
                if (uri.contains("vidsrc") ||
                    uri.contains("vapi") ||
                    uri.contains("static")) {
                  return NavigationActionPolicy.ALLOW;
                }

                // Solo bloqueamos si el host es claramente de anuncios (popups)
                if (navigationAction.isForMainFrame) {
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
            ),

            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
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
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        // Agregado para evitar error de overflow en títulos largos
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
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
