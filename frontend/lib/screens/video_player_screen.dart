import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/settings_provider.dart';

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
  bool _isLoading = true;
  bool _isScraping = false;
  String? _errorMessage;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  // Lista de servidores con redundancia - Primario + Backup
  final List<String> _apiServers = [
    'https://projectstreaming-1.onrender.com', // Primario
  ];

  // Lista de proveedores para scraping con soporte multi-proveedor
  final List<Map<String, String>> _providers = [
    {"name": "VidSrc (.ru)", "baseUrl": "https://vsembed.ru/embed/"},
    {"name": "VidSrc (.su)", "baseUrl": "https://vsembed.su/embed/"},
    {"name": "DoodStream", "baseUrl": "https://doodstream.com/"},
    {"name": "StreamTape", "baseUrl": "https://streamtape.com/"},
    {"name": "MixDrop", "baseUrl": "https://mixdrop.co/"},
    {"name": "SuperVideo/Fembed", "baseUrl": "https://fembed.com/"},
  ];

  // Proveedor actual seleccionado
  int _currentProviderIndex = 0;
  // Intentos de scraping realizados
  int _scrapingAttempts = 0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.season != widget.season ||
        oldWidget.episode != widget.episode ||
        oldWidget.tmdbId != widget.tmdbId) {
      _initPlayer();
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    _chewieController?.dispose();
    _chewieController = null;

    if (_videoPlayerController != null) {
      await _videoPlayerController!.dispose();
      _videoPlayerController = null;
    }

    setState(() {
      _isLoading = true;
      _isScraping = true;
      _errorMessage = null;
      _scrapingAttempts = 0;
    });

    try {
      String? videoUrl;
      Exception? lastError;

      // Intentar con cada proveedor en orden
      for (int i = 0; i < _providers.length; i++) {
        _currentProviderIndex = i;
        _scrapingAttempts++;

        final String targetUrl = _generateUrl(providerIndex: i);
        print('🎯 Intentando proveedor ${_providers[i]['name']}: $targetUrl');

        try {
          videoUrl = await _fetchVideoUrl(targetUrl);
          if (videoUrl != null) {
            print('✅ Éxito con proveedor ${_providers[i]['name']}: $videoUrl');
            break;
          }
        } catch (error) {
          lastError = error is Exception ? error : Exception(error.toString());
          print(
            '⚠️  Proveedor ${_providers[i]['name']} falló: ${error.toString()}',
          );

          _chewieController?.dispose();
          _chewieController = null;
          if (_videoPlayerController != null) {
            await _videoPlayerController!.dispose();
            _videoPlayerController = null;
          }

          // Pequeña pausa entre intentos (excepto después del último)
          if (i < _providers.length - 1) {
            await Future.delayed(const Duration(milliseconds: 800));
          }
        }
      }

      if (videoUrl == null) {
        throw lastError ?? Exception('Todos los proveedores fallaron');
      }

      // Configurar el controlador de video para HLS (.m3u8)
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
        httpHeaders: {
          'Referer': 'https://projectstreaming-1.onrender.com',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Origin': 'https://oglingling.github.io',
        },
      );

      await _videoPlayerController!.initialize();

      // Configurar ChewieController con controles avanzados
      _chewieController?.dispose();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey[300]!,
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: Colors.redAccent),
          ),
        ),
        autoInitialize: true,
        showOptions: true,
        allowedScreenSleep: false,
        isLive: false,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isScraping = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isScraping = false;
        _errorMessage = error.toString();
      });

      _showErrorDialog(error.toString());
    }
  }

  Future<String?> _fetchVideoUrl(String targetUrl) async {
    Exception? lastError;

    // Intentar con cada servidor en orden (redundancia)
    for (int i = 0; i < _apiServers.length; i++) {
      final String serverUrl = _apiServers[i];

      // Construir URL con parámetros de tracking para watchlist
      String apiUrl =
          '$serverUrl/api/extract?url=${Uri.encodeComponent(targetUrl)}';

      // Agregar parámetros de contenido para tracking en watchlist
      if (widget.tmdbId != null) {
        apiUrl += '&contentId=${widget.tmdbId}';
      }
      if (widget.imdbId != null) {
        apiUrl += '&imdbId=${widget.imdbId}';
      }
      apiUrl += '&title=${Uri.encodeComponent(widget.title)}';
      apiUrl += '&type=${widget.type}';

      print('🔍 Intentando servidor ${i + 1}: $serverUrl');

      try {
        final response = await http
            .get(
              Uri.parse(apiUrl),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Referer': 'https://projectstreaming-1.onrender.com',
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['success'] == true) {
            print('✅ Éxito con servidor ${i + 1}: $serverUrl');

            // Registrar en analytics si está disponible
            if (data['analytics'] != null) {
              print('📊 Analytics: ${data['analytics']}');
            }

            return data['streamUrl'];
          } else {
            lastError = Exception(data['error'] ?? 'Error en el scraping');
            print('⚠️  Servidor ${i + 1} falló: ${data['error']}');
          }
        } else {
          lastError = Exception('Error HTTP ${response.statusCode}');
          print('⚠️  Servidor ${i + 1} falló: HTTP ${response.statusCode}');
        }
      } catch (error) {
        lastError = error is Exception ? error : Exception(error.toString());
        print('⚠️  Servidor ${i + 1} falló: ${error.toString()}');
      }

      // Pequeña pausa entre intentos (excepto después del último)
      if (i < _apiServers.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Si todos los servidores fallaron, lanzar el último error
    throw lastError ?? Exception('Todos los servidores fallaron');
  }

  void _showProviderSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar servidor'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _providers.length,
            itemBuilder: (context, index) {
              final provider = _providers[index];
              return ListTile(
                leading: Icon(
                  index == _currentProviderIndex
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: index == _currentProviderIndex
                      ? Colors.redAccent
                      : Colors.grey,
                ),
                title: Text(provider['name']!),
                subtitle: Text(provider['baseUrl']!),
                onTap: () {
                  Navigator.pop(context);
                  if (index != _currentProviderIndex) {
                    setState(() {
                      _currentProviderIndex = index;
                    });
                    _initPlayer(); // Recargar con nuevo proveedor
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error al cargar el video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.contains('Timeout')
                  ? 'El servidor tardó demasiado en responder'
                  : error.contains('404')
                  ? 'No se encontró el video en los servidores disponibles'
                  : error.contains('500')
                  ? 'Error interno del servidor de streaming'
                  : 'Error: $error',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Intentos realizados: $_scrapingAttempts proveedores',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initPlayer(); // Reintentar
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar con otro servidor'),
          ),
        ],
      ),
    );
  }

  String _generateUrl({int? providerIndex}) {
    final provider = _providers[providerIndex ?? _currentProviderIndex];
    final isTV =
        widget.type.toLowerCase().contains('serie') ||
        widget.type.toLowerCase().contains('tv');
    String id = widget.tmdbId ?? widget.imdbId ?? "";
    String mediaType = isTV ? "tv" : "movie";

    // Lógica específica por proveedor
    String baseUrl = provider['baseUrl']!;

    if (baseUrl.contains('doodstream')) {
      return "$baseUrl$id";
    } else if (baseUrl.contains('streamtape')) {
      return "$baseUrl/v/$id";
    } else if (baseUrl.contains('mixdrop')) {
      return "$baseUrl/e/$id";
    } else if (baseUrl.contains('fembed')) {
      return "$baseUrl/v/$id";
    } else {
      // Proveedores VidSrc (compatibilidad con formato anterior)
      return "${baseUrl}$mediaType?tmdb=$id${isTV ? "&season=${widget.season}&episode=${widget.episode}" : ""}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            if (widget.type.toLowerCase().contains('tv'))
              Text(
                "T${widget.season} • E${widget.episode}",
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
          ],
        ),
        actions: [
          // Selector de proveedores
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: _showProviderSelector,
              tooltip: 'Seleccionar servidor',
            ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return Stack(
            children: [
              // Video Player con Chewie
              if (_chewieController != null && !_isLoading)
                Center(child: Chewie(controller: _chewieController!)),

              // Loading Indicator durante scraping con información de proveedores
              if (_isScraping)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Buscando el mejor servidor... (Intento $_scrapingAttempts)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _scrapingAttempts > 0 &&
                                _scrapingAttempts <= _providers.length
                            ? 'Probando: ${_providers[_scrapingAttempts - 1]['name']}'
                            : 'Analizando proveedores disponibles',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              // Loading Indicator general
              if (_isLoading && !_isScraping)
                const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                ),
              // --- CAPA DE SUBTÍTULOS (OVERLAY) ---
              if (settings.showSubtitles)
                Positioned(
                  bottom: 30, // Separación del borde inferior
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    // Para que los toques pasen al video (Play/Pause)
                    child: Container(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        // NOTA: Este es un texto simulado. En una implementación real con SRT/VTT,
                        // deberías parsear el archivo y actualizar este texto dinámicamente según el tiempo del video.
                        child: Text(
                          "Los subtítulos propios se mostrarán aquí...",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: settings.subtitleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(
                                offset: Offset(-1.5, -1.5),
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: Offset(1.5, -1.5),
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: Offset(1.5, 1.5),
                                color: Colors.black,
                              ),
                              Shadow(
                                offset: Offset(-1.5, 1.5),
                                color: Colors.black,
                              ),
                              Shadow(blurRadius: 4.0, color: Colors.black),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
