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
    String id = widget.tmdbId ?? widget.imdbId ?? "";
    String mediaType = isTV ? "tv" : "movie";

    if (provider['name'] == "Vidsrc.pro" || provider['name'] == "Embed.su") {
      return WebUri(
        "${provider['baseUrl']}$mediaType/$id${isTV ? "/${widget.season}/${widget.episode}" : ""}",
      );
    }
    if (provider['name'] == "Vidsrc.me") {
      return WebUri(
        "${provider['baseUrl']}$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}",
      );
    }
    return WebUri(
      "${provider['baseUrl']}$mediaType/$id${isTV ? "/${widget.season}/${widget.episode}" : ""}",
    );
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
          ActionChip(
            label: Text("Server: ${_providers[_currentProviderIndex]['name']}"),
            onPressed: () {
              setState(() {
                _currentProviderIndex =
                    (_currentProviderIndex + 1) % _providers.length;
                _isLoading = true;
              });
              _webViewController?.loadUrl(
                urlRequest: URLRequest(url: _generateUrl()),
              );
            },
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
              // UserAgent es obligatorio para evitar que te detecten como Bot
              userAgent:
                  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
            ),
            onWebViewCreated: (controller) => _webViewController = controller,
            onLoadStop: (controller, url) => setState(() => _isLoading = false),
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
