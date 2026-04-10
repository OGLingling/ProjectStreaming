import 'dart:ui_web' as ui; // Importante para Flutter 3.19+
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web; // Paquete 'web' oficial

class WebVideoPlayer extends StatelessWidget {
  final String url;

  WebVideoPlayer({required this.url}) {
    // Registramos la vista del iFrame con las políticas que saltan el Sandbox
    ui.platformViewRegistry.registerViewFactory('video-iframe', (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      // Esta es la clave que encontraste en vidsrc:
      // permite que el reproductor sepa de dónde viene sin bloquearse
      iframe.setAttribute('referrerpolicy', 'origin');
      iframe.setAttribute('allow', 'autoplay; fullscreen; picture-in-picture');

      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: 'video-iframe');
  }
}
