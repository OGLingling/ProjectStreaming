import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

enum EmbedProvider { multiEmbed, smashyStream }

class VideoPlayerScreen extends StatefulWidget {
  final String? tmdbId;
  final String? imdbId;
  final String? directUrl;
  final String title;
  final String type;
  final int season;
  final int episode;

  const VideoPlayerScreen({
    super.key,
    this.tmdbId,
    this.imdbId,
    this.directUrl,
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
  EmbedProvider _provider = EmbedProvider.multiEmbed;
  bool _isLoading = true;
  String? _loadError;

  String get _normalizedMediaType {
    final type = widget.type.toLowerCase();
    return type.contains('serie') || type.contains('tv') ? 'tv' : 'movie';
  }

  Map<String, String> get _mobileHeaders {
    final uri = Uri.tryParse(_currentEmbedUrl);
    final origin = uri?.origin ?? 'https://multiembed.mov';

    return {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      'Referer': '$origin/',
      'Origin': origin,
      'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
    };
  }

  String get _currentEmbedUrl {
    final tmdbId = widget.tmdbId?.trim();
    if (tmdbId == null || tmdbId.isEmpty) {
      return widget.directUrl?.trim() ?? '';
    }

    final isTv = _normalizedMediaType == 'tv';
    switch (_provider) {
      case EmbedProvider.multiEmbed:
        final params = {
          'video_id': tmdbId,
          'tmdb': '1',
          if (isTv) 's': widget.season.toString(),
          if (isTv) 'e': widget.episode.toString(),
        };
        return Uri.https('multiembed.mov', '/', params).toString();
      case EmbedProvider.smashyStream:
        final params = {
          'tmdb': tmdbId,
          if (isTv) 'season': widget.season.toString(),
          if (isTv) 'episode': widget.episode.toString(),
        };
        return Uri.https(
          'embed.smashystream.com',
          '/playere.php',
          params,
        ).toString();
    }
  }

  String get _providerName {
    switch (_provider) {
      case EmbedProvider.multiEmbed:
        return 'MultiEmbed';
      case EmbedProvider.smashyStream:
        return 'SmashyStream';
    }
  }

  @override
  void initState() {
    super.initState();
    _enterPlaybackMode();
  }

  @override
  void dispose() {
    _exitPlaybackMode();
    super.dispose();
  }

  Future<void> _enterPlaybackMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitPlaybackMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _reloadProvider(EmbedProvider provider) async {
    if (_provider == provider) return;
    setState(() {
      _provider = provider;
      _isLoading = true;
      _loadError = null;
    });

    final url = _currentEmbedUrl;
    if (url.isNotEmpty) {
      await _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url), headers: _mobileHeaders),
      );
    }
  }

  Future<void> _reloadCurrent() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    await _webViewController?.reload();
  }

  Widget _buildProviderButton(EmbedProvider provider) {
    final selected = _provider == provider;
    final label = provider == EmbedProvider.multiEmbed
        ? 'MultiEmbed'
        : 'SmashyStream';

    return TextButton(
      onPressed: () => _reloadProvider(provider),
      style: TextButton.styleFrom(
        foregroundColor: selected ? Colors.black : Colors.white,
        backgroundColor: selected ? const Color(0xFF00D46A) : Colors.white12,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final embedUrl = _currentEmbedUrl;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              if (embedUrl.isNotEmpty)
                InAppWebView(
                  key: ValueKey(embedUrl),
                  initialUrlRequest: URLRequest(
                    url: WebUri(embedUrl),
                    headers: _mobileHeaders,
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    iframeAllowFullscreen: true,
                    supportZoom: false,
                    transparentBackground: false,
                    useShouldOverrideUrlLoading: true,
                    mixedContentMode:
                        MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    thirdPartyCookiesEnabled: true,
                    domStorageEnabled: true,
                    userAgent: _mobileHeaders['User-Agent'],
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    if (!mounted) return;
                    setState(() {
                      _isLoading = true;
                      _loadError = null;
                    });
                  },
                  onLoadStop: (controller, url) {
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                  },
                  onReceivedError: (_, request, error) {
                    if (request.isForMainFrame != true || !mounted) return;
                    setState(() {
                      _isLoading = false;
                      _loadError = error.description;
                    });
                  },
                  onReceivedHttpError: (_, request, response) {
                    if (request.isForMainFrame != true || !mounted) return;
                    setState(() {
                      _isLoading = false;
                      _loadError = 'HTTP ${response.statusCode}';
                    });
                  },
                  shouldOverrideUrlLoading: (controller, action) async {
                    if (action.isForMainFrame == false) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    final url = action.request.url?.toString() ?? '';
                    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
                    final allowedHost = _provider == EmbedProvider.multiEmbed
                        ? 'multiembed.mov'
                        : 'embed.smashystream.com';

                    if (host.isEmpty ||
                        host == allowedHost ||
                        host.endsWith('.$allowedHost')) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    return NavigationActionPolicy.CANCEL;
                  },
                )
              else
                const Center(
                  child: Text(
                    'Contenido no disponible',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.title} - $_providerName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildProviderButton(EmbedProvider.multiEmbed),
                    const SizedBox(width: 8),
                    _buildProviderButton(EmbedProvider.smashyStream),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _reloadCurrent,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D46A)),
                ),
              if (_loadError != null)
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1F22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _reloadCurrent,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
