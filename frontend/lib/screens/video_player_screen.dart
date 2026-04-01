import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'; // Nuevo import

class VideoPlayerScreen extends StatefulWidget {
  final String
  imdbId; // Cambiamos URL por el ID de la película (ej. tt10155932)
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.imdbId,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _showControls = true;
  Timer? _hideTimer;
  InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();

    // 1. CONFIGURACIÓN DE PANTALLA (Igual que el tuyo)
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
            // 1. EL REPRODUCTOR (WEBVIEW)
            // Usamos vidsrc.to que es el más estable para este método
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri("https://vidsrc.to/embed/movie/${widget.imdbId}"),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowsInlineMediaPlayback: true, // Crucial para iOS
                mediaPlaybackRequiresUserGesture: false,
                transparentBackground: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
            ),

            // 2. CAPA NEGRA SUPERIOR E INFERIOR (Solo visual para tus controles)
            if (_showControls) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
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
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Nota: Los controles de Play/Pause y Barra de progreso
            // ahora son manejados por el reproductor web mismo.
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 2. RESTABLECER PANTALLA AL SALIR (Igual que el tuyo)
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _hideTimer?.cancel();
    super.dispose();
  }
}
