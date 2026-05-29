import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

/// Un reproductor de video híbrido inteligente en Flutter.
/// Si la URL es un stream directo, utiliza video_player y chewie nativo.
/// Si no, actúa como fallback y renderiza la lógica del WebView embebido actual.
class HybridVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final Map<String, String>? headers;
  final bool showSubtitles;
  final Color subtitleColor;
  final String? subtitleUrl;
  final String subtitleLanguage;
  final String subtitleLabel;
  final void Function(InAppWebViewController)? onWebViewCreated;
  final void Function(InAppWebViewController, WebUri?)? onLoadStart;
  final void Function(InAppWebViewController, WebUri?)? onLoadStop;
  final void Function(
    InAppWebViewController,
    WebResourceRequest,
    WebResourceError,
  )?
  onReceivedError;
  final void Function(
    InAppWebViewController,
    WebResourceRequest,
    WebResourceResponse,
  )?
  onReceivedHttpError;
  final VoidCallback? onNativePlaybackFailed;
  final ValueChanged<String>? onNativeUrlFound;
  final bool allowNativeUrlPromotion;

  const HybridVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    this.headers,
    this.showSubtitles = true,
    this.subtitleColor = Colors.white,
    this.subtitleUrl,
    this.subtitleLanguage = 'es-419',
    this.subtitleLabel = 'Espanol Latino',
    this.onWebViewCreated,
    this.onLoadStart,
    this.onLoadStop,
    this.onReceivedError,
    this.onReceivedHttpError,
    this.onNativePlaybackFailed,
    this.onNativeUrlFound,
    this.allowNativeUrlPromotion = true,
  });

  @override
  State<HybridVideoPlayer> createState() => _HybridVideoPlayerState();
}

class _HybridVideoPlayerState extends State<HybridVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _usesNativePlayer = false;
  bool _isInitializing = true;
  String? _initError;
  bool _nativeErrorReported = false;
  bool _nativeUrlReported = false;

  // Lógica de adblock / hosts bloqueados idéntica a la original
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static const List<String> _blockedHostHints = [
    'doubleclick',
    'googlesyndication',
    'google-analytics',
    'adservice',
    'adsterra',
    'popads',
    'propeller',
    'taboola',
    'onclick',
    'exoclick',
    'trafficjunky',
  ];

  @override
  void initState() {
    super.initState();
    _checkUrlAndInitialize();
  }

  @override
  void didUpdateWidget(covariant HybridVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl == widget.videoUrl) {
      if (_usesNativePlayer &&
          _videoPlayerController?.value.isInitialized == true &&
          (oldWidget.showSubtitles != widget.showSubtitles ||
              oldWidget.subtitleUrl != widget.subtitleUrl)) {
        _loadNativeCaptions(Uri.parse(widget.videoUrl.trim()));
      }
      return;
    }

    _disposeNativeControllers();
    _isInitializing = true;
    _initError = null;
    _nativeErrorReported = false;
    _nativeUrlReported = false;
    _checkUrlAndInitialize();
  }

  /// Fase de decisión (Smart Router):
  /// Evalúa si la URL es un stream directo reproducible.
  void _checkUrlAndInitialize() {
    final lowerUrl = widget.videoUrl.toLowerCase();
    _usesNativePlayer = _isNativePlayableUrl(lowerUrl);

    if (_usesNativePlayer) {
      _initializeNative();
    } else {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  /// Inicialización del reproductor nativo (video_player + chewie)
  Future<void> _initializeNative() async {
    try {
      final uri = Uri.parse(widget.videoUrl.trim());
      _videoPlayerController = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: widget.headers ?? {},
      );
      _videoPlayerController!.addListener(_handleNativePlaybackState);

      await _videoPlayerController!.initialize();
      await _loadNativeCaptions(uri);

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        showControls: true,
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF00D46A),
          handleColor: const Color(0xFF00D46A),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF00D46A),
          handleColor: const Color(0xFF00D46A),
        ),
        // Error builder elegante en español
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(24),
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
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Error de Reproducción Nativa',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
          _isInitializing = false;
        });
      }
      widget.onNativePlaybackFailed?.call();
    }
  }

  Future<void> _loadNativeCaptions(Uri videoUri) async {
    if (!widget.showSubtitles) {
      await _videoPlayerController?.setClosedCaptionFile(null);
      if (mounted) setState(() {});
      return;
    }

    final ownSubtitleUrl = widget.subtitleUrl?.trim();
    if (ownSubtitleUrl != null && ownSubtitleUrl.isNotEmpty) {
      final ownSubtitleUri = _resolveCaptionUri(videoUri, ownSubtitleUrl);
      if (ownSubtitleUri != null && await _loadCaptionUri(ownSubtitleUri)) {
        return;
      }
    }

    final subtitleUri = await _findSubtitleUri(videoUri);
    if (subtitleUri == null) {
      await _videoPlayerController?.setClosedCaptionFile(null);
      if (mounted) setState(() {});
      return;
    }

    await _loadCaptionUri(subtitleUri);
  }

  Future<bool> _loadCaptionUri(Uri subtitleUri) async {
    try {
      final response = await _getCaptionResponse(subtitleUri);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final captionBody = _looksLikeHlsManifest(body, subtitleUri)
          ? await _loadHlsCaptionPlaylist(body, subtitleUri)
          : body;

      if (captionBody == null || captionBody.trim().isEmpty) return false;

      final captionFile = _parseCaptionFile(captionBody, subtitleUri);

      await _videoPlayerController?.setClosedCaptionFile(
        Future<ClosedCaptionFile>.value(captionFile),
      );
      if (mounted) setState(() {});
      return true;
    } catch (_) {
      // Some HLS providers expose subtitle tracks that are not reachable directly.
      return false;
    }
  }

  ClosedCaptionFile _parseCaptionFile(String body, Uri subtitleUri) {
    final path = subtitleUri.path.toLowerCase();
    final trimmed = body.replaceFirst('\uFEFF', '').trimLeft();
    final looksLikeSrt =
        path.endsWith('.srt') ||
        RegExp(
          r'^\d+\s*\r?\n\d{2}:\d{2}:\d{2}[,.]\d{3}',
          multiLine: true,
        ).hasMatch(trimmed);

    return looksLikeSrt
        ? SubRipCaptionFile(trimmed)
        : WebVTTCaptionFile(_ensureWebVttHeader(trimmed));
  }

  Uri? _resolveCaptionUri(Uri videoUri, String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    return uri.hasScheme ? uri : videoUri.resolveUri(uri);
  }

  Future<http.Response> _getCaptionResponse(Uri uri) async {
    final attempts = [
      _headersForCaptionUri(uri),
      widget.headers ?? const <String, String>{},
      const <String, String>{},
    ];

    Object? lastError;
    for (final headers in attempts) {
      try {
        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception('Caption request failed: $lastError');
  }

  Map<String, String> _headersForCaptionUri(Uri uri) {
    final headers = Map<String, String>.from(widget.headers ?? {});
    headers.putIfAbsent('User-Agent', () => _desktopUserAgent);
    headers.putIfAbsent(
      'Accept',
      () => 'text/vtt,text/plain,application/x-subrip,*/*',
    );
    headers.putIfAbsent(
      'Accept-Language',
      () => 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
    );
    headers.putIfAbsent('Referer', () => '${uri.origin}/');
    headers.putIfAbsent('Origin', () => uri.origin);
    return headers;
  }

  bool _looksLikeHlsManifest(String body, Uri uri) {
    final lowerPath = uri.path.toLowerCase();
    return lowerPath.endsWith('.m3u8') || body.trimLeft().startsWith('#EXTM3U');
  }

  Future<String?> _loadHlsCaptionPlaylist(
    String manifest,
    Uri playlistUri,
  ) async {
    final segmentUris = manifest
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map(playlistUri.resolve)
        .where(
          (uri) =>
              uri.path.toLowerCase().endsWith('.vtt') ||
              uri.path.toLowerCase().endsWith('.srt'),
        )
        .take(8)
        .toList();

    if (segmentUris.isEmpty) return null;

    final chunks = <String>[];
    for (final uri in segmentUris) {
      final response = await _getCaptionResponse(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) continue;
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final cleaned = body
          .replaceFirst('\uFEFF', '')
          .replaceFirst(RegExp(r'^WEBVTT[^\n\r]*(\r?\n)+'), '')
          .trim();
      if (cleaned.isNotEmpty) chunks.add(cleaned);
    }

    if (chunks.isEmpty) return null;
    return 'WEBVTT\n\n${chunks.join('\n\n')}';
  }

  String _ensureWebVttHeader(String body) {
    return body.startsWith('WEBVTT') ? body : 'WEBVTT\n\n$body';
  }

  Future<Uri?> _findSubtitleUri(Uri videoUri) async {
    try {
      final response = await http
          .get(videoUri, headers: widget.headers ?? {})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final manifest = utf8.decode(response.bodyBytes, allowMalformed: true);
      final mediaLines = manifest
          .split('\n')
          .map((line) => line.trim())
          .where(
            (line) =>
                line.startsWith('#EXT-X-MEDIA') &&
                line.toUpperCase().contains('TYPE=SUBTITLES'),
          )
          .toList();

      if (mediaLines.isEmpty) return null;

      mediaLines.sort(
        (a, b) => _subtitleLineScore(b).compareTo(_subtitleLineScore(a)),
      );

      final uriValue = _readHlsAttribute(mediaLines.first, 'URI');
      if (uriValue == null || uriValue.isEmpty) return null;

      return videoUri.resolve(uriValue);
    } catch (_) {
      return null;
    }
  }

  int _subtitleLineScore(String line) {
    final lower = line.toLowerCase();
    final requestedLanguage = widget.subtitleLanguage.toLowerCase();
    var score = 0;
    if (lower.contains('default=yes')) score += 4;
    if (lower.contains('forced=no')) score += 2;
    if (requestedLanguage.isNotEmpty &&
        (lower.contains('language="$requestedLanguage"') ||
            lower.contains('language=$requestedLanguage'))) {
      score += 12;
    }
    if (lower.contains(widget.subtitleLabel.toLowerCase())) score += 10;
    if (lower.contains('language="es"') ||
        lower.contains('language=es') ||
        lower.contains('language="spa"') ||
        lower.contains('language=spa') ||
        lower.contains('language="es-es"') ||
        lower.contains('language=es-es') ||
        lower.contains('language="es-419"') ||
        lower.contains('language=es-419') ||
        lower.contains('spanish') ||
        lower.contains('castellano') ||
        lower.contains('latino') ||
        lower.contains('espanol') ||
        lower.contains('español')) {
      score += 8;
    }
    return score;
  }

  String? _readHlsAttribute(String line, String key) {
    final match = RegExp('(?:^|,)$key=(?:"([^"]*)"|([^,]*))').firstMatch(line);
    return match?.group(1) ?? match?.group(2);
  }

  void _handleNativePlaybackState() {
    final controller = _videoPlayerController;
    if (controller == null ||
        _nativeErrorReported ||
        !controller.value.hasError) {
      return;
    }

    _nativeErrorReported = true;
    widget.onNativePlaybackFailed?.call();
  }

  /// Limpieza de adblock / hosts de navegación
  bool _isBlockedNavigation(String url) {
    final lower = url.toLowerCase();
    if (lower == 'about:blank') return true;
    return _blockedHostHints.any(lower.contains);
  }

  bool _isPlayableUrl(String url) {
    return _isNativePlayableUrl(url);
  }

  bool _isNativePlayableUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('googlevideo.com/videoplayback') ||
        lower.contains('application/x-mpegurl');
  }

  void _reportNativeUrl(String url) {
    if (!widget.allowNativeUrlPromotion ||
        _nativeUrlReported ||
        _usesNativePlayer ||
        !_isPlayableUrl(url)) {
      return;
    }
    _nativeUrlReported = true;
    widget.onNativeUrlFound?.call(url);
  }

  /// Gestión de Memoria: Liberar recursos de los controladores
  @override
  void dispose() {
    _disposeNativeControllers();
    super.dispose();
  }

  void _disposeNativeControllers() {
    _videoPlayerController?.removeListener(_handleNativePlaybackState);
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_usesNativePlayer) {
      // --- RENDERIZACIÓN NATIVA (HLS / MP4 / streams directos) ---
      if (_isInitializing) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D46A)),
        );
      }

      if (_initError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'No se pudo cargar el stream nativo:\n$_initError',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      if (_chewieController != null &&
          _videoPlayerController!.value.isInitialized) {
        return Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Chewie(controller: _chewieController!),
                if (widget.showSubtitles) _buildNativeCaptionOverlay(),
              ],
            ),
          ),
        );
      }

      return const Center(
        child: Text(
          'Error al inicializar el video nativo',
          style: TextStyle(color: Colors.white70),
        ),
      );
    } else {
      // --- RENDERIZACIÓN WEBVIEW DE FALLBACK (TuWidgetActualDeWebView) ---
      final origin = Uri.tryParse(widget.videoUrl)?.origin ?? '';
      final headers =
          widget.headers ??
          {
            'User-Agent': _desktopUserAgent,
            'Referer': '$origin/',
            'Origin': origin,
            'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
          };

      return InAppWebView(
        key: ValueKey(widget.videoUrl),
        initialUrlRequest: URLRequest(
          url: WebUri(widget.videoUrl),
          headers: headers,
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          javaScriptCanOpenWindowsAutomatically: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          iframeAllowFullscreen: true,
          supportZoom: false,
          transparentBackground: false,
          useShouldOverrideUrlLoading: true,
          useShouldInterceptRequest: true,
          useOnLoadResource: true,
          supportMultipleWindows: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          thirdPartyCookiesEnabled: true,
          domStorageEnabled: true,
          userAgent: headers['User-Agent'] ?? _desktopUserAgent,
        ),
        onWebViewCreated: widget.onWebViewCreated,
        onLoadStart: widget.onLoadStart,
        onLoadStop: widget.onLoadStop,
        onLoadResource: (controller, resource) {
          _reportNativeUrl(resource.url.toString());
        },
        onReceivedError: widget.onReceivedError,
        onReceivedHttpError: widget.onReceivedHttpError,
        onPermissionRequest: (controller, request) async {
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        },
        onCreateWindow: (controller, request) async {
          return false;
        },
        shouldInterceptRequest: (controller, request) async {
          _reportNativeUrl(request.url.toString());
          return null;
        },
        shouldOverrideUrlLoading: (controller, action) async {
          final url = action.request.url?.toString() ?? '';
          _reportNativeUrl(url);
          if (_isBlockedNavigation(url)) {
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      );
    }
  }

  Widget _buildNativeCaptionOverlay() {
    final controller = _videoPlayerController;
    if (controller == null) return const SizedBox.shrink();

    return Positioned(
      left: 16,
      right: 16,
      bottom: 48,
      child: IgnorePointer(
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            final text = value.caption.text.trim();
            if (text.isEmpty) return const SizedBox.shrink();

            return Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.subtitleColor,
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(
                          blurRadius: 3,
                          color: Colors.black,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
