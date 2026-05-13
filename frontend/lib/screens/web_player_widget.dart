import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebPlayerWidget extends StatefulWidget {
  final String urlEmbed;
  final ValueChanged<String> onVideoFound;
  final ValueChanged<String> onLoadFailed;
  final bool captureOnly;

  const WebPlayerWidget({
    super.key,
    required this.urlEmbed,
    required this.onVideoFound,
    required this.onLoadFailed,
    this.captureOnly = true,
  });

  @override
  State<WebPlayerWidget> createState() => _WebPlayerWidgetState();
}

class _WebPlayerWidgetState extends State<WebPlayerWidget> {
  bool _hasReportedVideo = false;
  bool _hasReportedLoadError = false;

  Map<String, String> get _mobileHeaders {
    final origin = WebUri(widget.urlEmbed).origin;
    return {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      'Referer': '$origin/',
      'Origin': origin,
      'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
    };
  }

  bool _isPlayableUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('googlevideo.com/videoplayback')) return true;
    if (lower.contains('.m3u8') || lower.contains('master.m3u8')) return true;
    if (lower.contains('application/x-mpegurl')) return true;
    if (lower.contains('.mp4')) return true;
    return false;
  }

  void _reportVideo(String url) {
    if (!widget.captureOnly || _hasReportedVideo || !mounted) return;
    _hasReportedVideo = true;
    widget.onVideoFound(url);
  }

  void _reportLoadError(String message) {
    if (!widget.captureOnly ||
        _hasReportedVideo ||
        _hasReportedLoadError ||
        !mounted) {
      return;
    }
    _hasReportedLoadError = true;
    widget.onLoadFailed(message);
  }

  @override
  Widget build(BuildContext context) {
    final webView = InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(widget.urlEmbed),
        headers: _mobileHeaders,
      ),
      initialSettings: InAppWebViewSettings(
        useShouldInterceptRequest: true,
        useOnLoadResource: true,
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        transparentBackground: widget.captureOnly,
        userAgent: _mobileHeaders['User-Agent'],
        iframeAllowFullscreen: true,
        supportZoom: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        thirdPartyCookiesEnabled: true,
        domStorageEnabled: true,
      ),
      onLoadResource: (controller, resource) {
        final url = resource.url.toString();
        if (_isPlayableUrl(url)) {
          debugPrint("Recurso de video detectado: $url");
          _reportVideo(url);
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true) {
          _reportLoadError("WebView error: ${error.description}");
        }
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        if (request.isForMainFrame == true &&
            errorResponse.statusCode != null) {
          _reportLoadError("HTTP ${errorResponse.statusCode}");
        }
      },
      shouldInterceptRequest: (controller, request) async {
        final url = request.url.toString();

        if (_isPlayableUrl(url)) {
          debugPrint("Enlace de video capturado: $url");
          _reportVideo(url);
        }

        return null;
      },
    );

    if (!widget.captureOnly) {
      return SizedBox.expand(child: webView);
    }

    return IgnorePointer(
      child: Opacity(opacity: 0.01, child: SizedBox.expand(child: webView)),
    );
  }
}
