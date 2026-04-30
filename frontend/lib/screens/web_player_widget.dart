import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebPlayerWidget extends StatelessWidget {
  final String urlEmbed;
  final Function(String) onVideoFound;

  const WebPlayerWidget({
    super.key,
    required this.urlEmbed,
    required this.onVideoFound,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1, // Tamaño mínimo para que el sistema lo procese
      width: 1,
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(urlEmbed)),
        initialSettings: InAppWebViewSettings(
          useShouldInterceptRequest:
              true, // Crucial para oler el tráfico de red
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
        shouldInterceptRequest: (controller, request) async {
          String url = request.url.toString();

          // Filtramos las peticiones buscando el archivo de video real
          if (url.contains(".m3u8") ||
              url.contains("master.m3u8") ||
              url.contains(".mp4")) {
            debugPrint("🎯 ¡Enlace de video capturado!: $url");
            onVideoFound(url);
          }
          return null;
        },
      ),
    );
  }
}
