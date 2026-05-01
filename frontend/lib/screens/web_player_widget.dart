import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebPlayerWidget extends StatefulWidget {
  final String urlEmbed;
  final ValueChanged<String> onVideoFound;
  final ValueChanged<String> onLoadFailed;

  const WebPlayerWidget({
    super.key,
    required this.urlEmbed,
    required this.onVideoFound,
    required this.onLoadFailed,
  });

  @override
  State<WebPlayerWidget> createState() => _WebPlayerWidgetState();
}

class _WebPlayerWidgetState extends State<WebPlayerWidget> {
  bool _hasReportedVideo = false;
  bool _hasReportedLoadError = false;

  bool _isPlayableUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('googlevideo.com/videoplayback')) return true;
    if (lower.contains('.m3u8') || lower.contains('master.m3u8')) return true;
    if (lower.contains('.mp4')) return true;
    return false;
  }

  void _reportVideo(String url) {
    if (_hasReportedVideo || !mounted) return;
    _hasReportedVideo = true;
    widget.onVideoFound(url);
  }

  void _reportLoadError(String message) {
    if (_hasReportedVideo || _hasReportedLoadError || !mounted) return;
    _hasReportedLoadError = true;
    widget.onLoadFailed(message);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: 1,
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.urlEmbed)),
        initialSettings: InAppWebViewSettings(
          useShouldInterceptRequest: true,
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          transparentBackground: true,
        ),
        onReceivedError: (controller, request, error) {
          if (request.isForMainFrame == true) {
            _reportLoadError("WebView error: ${error.description}");
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          if (request.isForMainFrame == true && errorResponse.statusCode != null) {
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
      ),
    );
  }
}
