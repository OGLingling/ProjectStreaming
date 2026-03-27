import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  Timer? _hideTimer;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();

    // 1. CONFIGURACIÓN DE PANTALLA (Modo Cine)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller =
        VideoPlayerController.networkUrl(
            Uri.parse(widget.videoUrl),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
              _controller.play();
              _startHideTimer();
              // Listener para actualizar el tiempo mientras se reproduce
              _controller.addListener(() => setState(() {}));
            }
          });
  }

  // Función útil para formatear la duración (00:00)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onMouseMove() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onHover: (_) => _onMouseMove(),
        onEnter: (_) => _onMouseMove(),
        cursor: _showControls
            ? SystemMouseCursors.basic
            : SystemMouseCursors.none,
        child: GestureDetector(
          onTap: _onMouseMove,
          child: Stack(
            children: [
              // 1. EL VIDEO
              Center(
                child: _controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : const CircularProgressIndicator(color: Colors.red),
              ),

              // 2. CAPA NEGRA SUPERIOR (Para que el botón de atrás se vea bien)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                ),
              ),

              // 3. BOTÓN ATRÁS
              Positioned(
                top: 20,
                left: 20,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: _showControls
                        ? () => Navigator.pop(context)
                        : null,
                  ),
                ),
              ),

              // 4. CONTROLES INFERIORES
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Barra de progreso con tiempo actual y total
                        Row(
                          children: [
                            Text(
                              _formatDuration(_controller.value.position),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            Expanded(
                              child: VideoProgressIndicator(
                                _controller,
                                allowScrubbing: true,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                colors: const VideoProgressColors(
                                  playedColor: Colors.red,
                                  bufferedColor: Colors.white24,
                                  backgroundColor: Colors.white10,
                                ),
                              ),
                            ),
                            Text(
                              _formatDuration(_controller.value.duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Play/Pause
                            IconButton(
                              icon: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 35,
                              ),
                              onPressed: () {
                                setState(() {
                                  _controller.value.isPlaying
                                      ? _controller.pause()
                                      : _controller.play();
                                });
                                _startHideTimer();
                              },
                            ),
                            const SizedBox(width: 10),
                            // Título
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Volumen
                            const Icon(
                              Icons.volume_up,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(
                              width: 100,
                              child: Slider(
                                value: _volume,
                                activeColor: Colors.red,
                                inactiveColor: Colors.white24,
                                onChanged: (value) {
                                  setState(() {
                                    _volume = value;
                                    _controller.setVolume(_volume);
                                  });
                                  _startHideTimer();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 2. RESTABLECER PANTALLA AL SALIR
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
