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

  // --- LISTA DE SERVIDORES OPTIMIZADOS PARA WEB ---
  final List<Map<String, String>> _providers = [
    {"name": "Vidsrc.pro", "baseUrl": "https://vidsrc.pro/embed/"},
    {"name": "Vidsrc.me", "baseUrl": "https://vidsrc.me/embed/"},
    {"name": "Embed.su", "baseUrl": "https://embed.su/embed/"},
    {"name": "VidLink", "baseUrl": "https://vidlink.pro/"},
  ];

  WebUri _generateUrl() {
    final provider = _providers[_currentProviderIndex];
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');

    String providerName = provider['name']!;
    String id = widget.tmdbId ?? widget.imdbId ?? "";
    String mediaType = isTV ? "tv" : "movie";

    // Formato para Vidsrc.pro y Embed.su: /movie/ID o /tv/ID/S/E
    if (providerName == "Vidsrc.pro" || providerName == "Embed.su") {
      String path = "$mediaType/$id";
      if (isTV) path += "/${widget.season}/${widget.episode}";
      return WebUri("${provider['baseUrl']}$path");
    }

    // Formato para Vidsrc.me: /movie?tmdb=ID
    if (providerName == "Vidsrc.me") {
      String path = "$mediaType?tmdb=$id";
      if (isTV) path += "&season=${widget.season}&episode=${widget.episode}";
      return WebUri("${provider['baseUrl']}$path");
    }

    // Fallback para VidLink
    String finalUrl = "${provider['baseUrl']}$mediaType/$id";
    if (isTV) finalUrl += "/${widget.season}/${widget.episode}";

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
              backgroundColor: Colors.indigoAccent.withOpacity(0.9),
              label: Text(
                "Server: ${_providers[_currentProviderIndex]['name']}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _switchServer,
              avatar: const Icon(Icons.dns, size: 14, color: Colors.white),
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
              javaScriptCanOpenWindowsAutomatically: false,
              mediaPlaybackRequiresUserGesture: false,
              // UserAgent real para evitar detecciones de bots en Web
              userAgent:
                  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
            ),
            onWebViewCreated: (controller) => _webViewController = controller,
            onLoadStop: (controller, url) {
              setState(() => _isLoading = false);
            },
            onCreateWindow: (controller, createWindowAction) async {
              // Bloqueo de popups publicitarios
              return false;
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.indigoAccent),
              ),
            ),
        ],
      ),
    );
  }
}
