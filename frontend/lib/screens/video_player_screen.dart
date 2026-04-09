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

  // --- NUEVA LISTA DE SERVIDORES ---
  final List<Map<String, String>> _providers = [
    {"name": "VidLink", "baseUrl": "https://vidlink.pro/"},
    {"name": "AutoEmbed", "baseUrl": "https://player.autoembed.cc/"},
    {
      "name": "SimpleEmbed",
      "baseUrl": "https://p2p.xyz/embed/",
    }, // Ejemplo de endpoint común
  ];

  WebUri _generateUrl() {
    final provider = _providers[_currentProviderIndex];
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');

    String finalUrl = "";
    String providerName = provider['name']!;
    String mediaType = isTV ? "tv" : "movie";
    String id = widget.tmdbId ?? widget.imdbId ?? "";

    // Cada servidor tiene su propia estructura de URL
    if (providerName == "VidLink") {
      // Formato: https://vidlink.pro/movie/ID o https://vidlink.pro/tv/ID/1/1
      finalUrl = "${provider['baseUrl']}$mediaType/$id";
      if (isTV) finalUrl += "/${widget.season}/${widget.episode}";
    } else if (providerName == "AutoEmbed") {
      // Formato: https://player.autoembed.cc/movie/ID o https://player.autoembed.cc/tv/ID/1/1
      finalUrl = "${provider['baseUrl']}$mediaType/$id";
      if (isTV) finalUrl += "/${widget.season}/${widget.episode}";
    } else if (providerName == "SimpleEmbed") {
      // Formato: https://p2p.xyz/embed/movie?tmdb=ID o tv?tmdb=ID&s=1&e=1
      finalUrl = "${provider['baseUrl']}$mediaType?tmdb=$id";
      if (isTV) finalUrl += "&s=${widget.season}&e=${widget.episode}";
    }

    return WebUri(finalUrl);
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
        elevation: 0,
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
              backgroundColor: Colors.blueAccent.withOpacity(0.8),
              label: Text(
                "Servidor: ${_providers[_currentProviderIndex]['name']}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _switchServer,
              avatar: const Icon(Icons.cyclone, size: 14, color: Colors.white),
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
              javaScriptCanOpenWindowsAutomatically: false, // Bloqueo de popups
              mediaPlaybackRequiresUserGesture: false,
              userAgent:
                  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            ),
            onWebViewCreated: (controller) => _webViewController = controller,
            onLoadStop: (controller, url) {
              setState(() => _isLoading = false);
            },
            // Seguridad reforzada contra publicidad
            onCreateWindow: (controller, createWindowAction) async {
              return false; // Evita que el WebView abra nuevas ventanas (publicidad)
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            ),
        ],
      ),
    );
  }
}
