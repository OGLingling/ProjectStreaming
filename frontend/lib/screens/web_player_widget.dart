import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class WebVideoPlayer extends StatelessWidget {
  final String url;
  final String
  contentId; // Necesitamos un ID único (ej. tmdbId + temporada + episodio)

  const WebVideoPlayer({super.key, required this.url, required this.contentId});

  @override
  Widget build(BuildContext context) {
    // Creamos un ID de vista único basado en el contenido y la URL
    // Esto fuerza a Flutter a registrar una nueva factoría si algo cambia
    final String viewType = 'video-player-$contentId';

    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      // Configuraciones de seguridad y compatibilidad
      iframe.setAttribute('referrerpolicy', 'origin');
      iframe.setAttribute(
        'allow',
        'autoplay; fullscreen; picture-in-picture; encrypted-media',
      );

      return iframe;
    });

    return HtmlElementView(
      key: ValueKey(viewType), // La key es vital para el refresco en Web
      viewType: viewType,
    );
  }
}
