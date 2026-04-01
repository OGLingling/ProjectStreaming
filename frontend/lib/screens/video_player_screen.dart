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

  // 1. ESTRUCTURA DE URL DINÁMICA
  WebUri _buildStreamingUrl() {
    final String cleanId = widget.imdbId.trim();
    final String cleanType = widget.type.toLowerCase().trim();

    // Detectamos si es película o serie
    final bool isTV = cleanType.contains('tv') || cleanType.contains('serie');

    // Construcción de la URL base
    // Si es serie, incluimos temporada 1 episodio 1 por defecto
    final String finalUrl = isTV
        ? "https://vidsrc.me/embed/tv/$cleanId/1/1"
        : "https://vidsrc.me/embed/movie/$cleanId";

    debugPrint("URL de Streaming Generada: $finalUrl");
    return WebUri(finalUrl);
  }

  @override
  void initState() {
    super.initState();
    // Bloqueamos orientación horizontal para video
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Ocultamos barras del sistema para inmersión total
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
            // 2. CONFIGURACIÓN DEL WIDGET INAPPWEBVIEW
            InAppWebView(
              initialUrlRequest: URLRequest(url: _buildStreamingUrl()),
              initialSettings: InAppWebViewSettings(
                // Configuración básica solicitada
                javaScriptEnabled: true,
                allowsInlineMediaPlayback: true,
                mediaPlaybackRequiresUserGesture: false,
                transparentBackground: true,

                // 3. SUPLANTACIÓN DE USER AGENT (Chrome Windows 11)
                userAgent:
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",

                // 4. CONFIGURACIÓN AVANZADA DE SEGURIDAD Y COOKIES
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                thirdPartyCookiesEnabled: true,
                javaScriptCanOpenWindowsAutomatically:
                    false, // Bloqueo preventivo de popups
                useShouldOverrideUrlLoading:
                    true, // Habilitar interceptor de navegación
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              // 5. MANEJO DE REDIRECCIONES Y BLOQUEO DE POPUPS
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url?.toString() ?? "";

                // Dominios permitidos (Fuentes de video y estáticos)
                final List<String> allowedDomains = [
                  "vidsrc.me",
                  "vidsrc.xyz",
                  "vapi.to",
                  "static.vidsrc.me",
                  "sbx.html", // Permitir archivos críticos
                  "sbx.js",
                ];

                // Verificamos si la URL contiene algún dominio permitido
                bool isAllowed = allowedDomains.any(
                  (domain) => uri.contains(domain),
                );

                if (isAllowed) {
                  return NavigationActionPolicy.ALLOW;
                }

                // Bloqueamos cualquier redirección fuera de los dominios de confianza (Popups/Ads)
                debugPrint("BLOQUEADO REDIRECCIÓN A: $uri");
                return NavigationActionPolicy.CANCEL;
              },
            ),

            // Capa de controles personalizados
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
    // Restauramos orientación al salir
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _webViewController?.stopLoading();
    _hideTimer?.cancel();
    super.dispose();
  }
}
