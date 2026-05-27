import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Un reproductor de video híbrido inteligente en Flutter.
/// Si la URL es de tipo HLS (.m3u8), utiliza video_player y chewie nativo.
/// Si no, actúa como fallback y renderiza la lógica del WebView embebido actual.
class HybridVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final Map<String, String>? headers;
  final void Function(InAppWebViewController)? onWebViewCreated;
  final void Function(InAppWebViewController, WebUri?)? onLoadStart;
  final void Function(InAppWebViewController, WebUri?)? onLoadStop;
  final void Function(InAppWebViewController, WebResourceRequest, WebResourceError)? onReceivedError;
  final void Function(InAppWebViewController, WebResourceRequest, WebResourceResponse)? onReceivedHttpError;

  const HybridVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    this.headers,
    this.onWebViewCreated,
    this.onLoadStart,
    this.onLoadStop,
    this.onReceivedError,
    this.onReceivedHttpError,
  });

  @override
  State<HybridVideoPlayer> createState() => _HybridVideoPlayerState();
}

class _HybridVideoPlayerState extends State<HybridVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isHls = false;
  bool _isInitializing = true;
  String? _initError;

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

  /// Fase de decisión (Smart Router):
  /// Evalúa si la URL es un archivo .m3u8 (HLS).
  void _checkUrlAndInitialize() {
    final lowerUrl = widget.videoUrl.toLowerCase();
    _isHls = lowerUrl.contains('.m3u8');

    if (_isHls) {
      _initializeNativo();
    } else {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  /// Inicialización del reproductor nativo (video_player + chewie)
  Future<void> _initializeNativo() async {
    try {
      final uri = Uri.parse(widget.videoUrl.trim());
      _videoPlayerController = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: widget.headers ?? {},
      );

      await _videoPlayerController!.initialize();

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
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'Error de Reproducción HLS',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
    }
  }

  /// Limpieza de adblock / hosts de navegación
  bool _isBlockedNavigation(String url) {
    final lower = url.toLowerCase();
    if (lower == 'about:blank') return true;
    return _blockedHostHints.any(lower.contains);
  }

  /// Gestión de Memoria: Liberar recursos de los controladores
  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isHls) {
      // --- RENDERIZACIÓN NATIVA (HLS / .m3u8) ---
      if (_isInitializing) {
        return const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00D46A),
          ),
        );
      }

      if (_initError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  'No se pudo cargar el stream HLS:\n$_initError',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      if (_chewieController != null && _videoPlayerController!.value.isInitialized) {
        return Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Chewie(controller: _chewieController!),
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
      final headers = widget.headers ?? {
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
          supportMultipleWindows: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          thirdPartyCookiesEnabled: true,
          domStorageEnabled: true,
          userAgent: headers['User-Agent'] ?? _desktopUserAgent,
        ),
        onWebViewCreated: widget.onWebViewCreated,
        onLoadStart: widget.onLoadStart,
        onLoadStop: widget.onLoadStop,
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
        shouldOverrideUrlLoading: (controller, action) async {
          final url = action.request.url?.toString() ?? '';
          if (_isBlockedNavigation(url)) {
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      );
    }
  }
}
