import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import 'hybrid_video_player.dart';

enum EmbedProvider { embed, vidSrcVip }

class VideoPlayerScreen extends StatefulWidget {
  final String? tmdbId;
  final String? imdbId;
  final int? contentId;
  final String? userId;
  final String? directUrl;
  final String title;
  final String type;
  final int season;
  final int episode;

  const VideoPlayerScreen({
    super.key,
    this.tmdbId,
    this.imdbId,
    this.contentId,
    this.userId,
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
  EmbedProvider _provider = EmbedProvider.embed;
  bool _isLoading = true;
  bool _showControls = true;
  String? _loadError;
  Timer? _controlsTimer;
  Timer? _progressTimer;
  late DateTime _playbackStartedAt;
  int _lastProgressSeconds = 0;
  int? _lastDurationSeconds;
  String? _nativeStreamUrl;
  bool _isResolvingNativeStream = false;
  bool _usingNativeStream = false;
  int _nativeResolveToken = 0;

  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  String get _normalizedMediaType {
    final type = widget.type.toLowerCase();
    return type.contains('serie') || type.contains('tv') ? 'tv' : 'movie';
  }

  Map<String, String> _headersForUrl(String url) {
    final lower = url.toLowerCase();
    if (_isDirectPlayableUrl(lower)) {
      return {
        'User-Agent': _desktopUserAgent,
        'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
      };
    }

    final uri = Uri.tryParse(url);
    final origin = uri?.origin ?? 'https://embed.streammafia.to';

    return {
      'User-Agent': _desktopUserAgent,
      'Referer': '$origin/',
      'Origin': origin,
      'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
    };
  }

  Map<String, String> get _mobileHeaders => _headersForUrl(_playbackUrl);

  String get _currentEmbedUrl {
    final tmdbId = widget.tmdbId?.trim();
    if (tmdbId == null || tmdbId.isEmpty) {
      return widget.directUrl?.trim() ?? '';
    }

    final isTv = _normalizedMediaType == 'tv';
    switch (_provider) {
      case EmbedProvider.embed:
        final path = isTv
            ? '/embed/tv/$tmdbId/${widget.season}/${widget.episode}'
            : '/embed/movie/$tmdbId';
        return Uri.https('embed.streammafia.to', path).toString();
      case EmbedProvider.vidSrcVip:
        final path = isTv
            ? '/embed/tv/$tmdbId/${widget.season}/${widget.episode}'
            : '/embed/movie/$tmdbId';
        return Uri.https('vidsrc.wiki', path, {
          'autoplay': '1',
          'color': '00d46a',
          'sub': 'es',
        }).toString();
    }
  }

  String get _playbackUrl {
    final nativeUrl = _nativeStreamUrl;
    if (_usingNativeStream && nativeUrl != null && nativeUrl.isNotEmpty) {
      return nativeUrl;
    }
    return _currentEmbedUrl;
  }

  String get _playbackLabel {
    return _usingNativeStream ? 'Player propio' : _providerName;
  }

  String get _providerName {
    switch (_provider) {
      case EmbedProvider.embed:
        return 'Embed';
      case EmbedProvider.vidSrcVip:
        return 'VidSrc VIP';
    }
  }

  bool _isDirectPlayableUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('googlevideo.com/videoplayback');
  }

  @override
  void initState() {
    super.initState();
    _playbackStartedAt = DateTime.now();
    _enterPlaybackMode();
    _scheduleControlsHide();
    _startProgressTracking();
    unawaited(_resolveNativeStream());
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _progressTimer?.cancel();
    unawaited(_saveViewingProgress());
    _exitPlaybackMode();
    super.dispose();
  }

  bool get _canPersistProgress {
    final userId = widget.userId?.trim();
    final tmdbId = widget.tmdbId?.trim();
    return userId != null &&
        userId.isNotEmpty &&
        ((widget.contentId != null && widget.contentId! > 0) ||
            (tmdbId != null && tmdbId.isNotEmpty));
  }

  void _startProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_saveViewingProgress());
    });
  }

  Future<Map<String, int?>> _readPlaybackPosition() async {
    try {
      final result = await _webViewController?.evaluateJavascript(
        source: '''
          (() => {
            const videos = Array.from(document.querySelectorAll('video'));
            const video = videos.find((item) => !item.paused) || videos[0];
            if (!video) return null;
            const duration = Number.isFinite(video.duration) ? Math.floor(video.duration) : null;
            return {
              progressSeconds: Math.floor(video.currentTime || 0),
              durationSeconds: duration,
              completed: Boolean(video.ended || (duration && video.currentTime / duration >= 0.92))
            };
          })();
        ''',
      );

      final parsed = result is String ? jsonDecode(result) : result;

      if (parsed is Map) {
        return {
          'progressSeconds': int.tryParse(parsed['progressSeconds'].toString()),
          'durationSeconds': parsed['durationSeconds'] == null
              ? null
              : int.tryParse(parsed['durationSeconds'].toString()),
          'completed': parsed['completed'] == true ? 1 : 0,
        };
      }
    } catch (_) {
      // Cross-origin iframes may hide the underlying video element.
    }

    return {
      'progressSeconds': DateTime.now()
          .difference(_playbackStartedAt)
          .inSeconds,
      'durationSeconds': _lastDurationSeconds,
      'completed': 0,
    };
  }

  Future<void> _saveViewingProgress({bool completed = false}) async {
    if (!_canPersistProgress) return;

    final position = await _readPlaybackPosition();
    final progressSeconds = position['progressSeconds'] ?? _lastProgressSeconds;
    final durationSeconds = position['durationSeconds'];
    final ended = completed || position['completed'] == 1;

    if (progressSeconds > _lastProgressSeconds) {
      _lastProgressSeconds = progressSeconds;
    }
    if (durationSeconds != null && durationSeconds > 0) {
      _lastDurationSeconds = durationSeconds;
    }

    if (ended) {
      await ApiService.completeViewingProgress(
        userId: widget.userId!.trim(),
        contentId: widget.contentId,
        tmdbId: widget.tmdbId,
        seasonNumber: widget.season,
        episodeNumber: widget.episode,
      );
      return;
    }

    await ApiService.saveViewingProgress(
      userId: widget.userId!.trim(),
      contentId: widget.contentId,
      tmdbId: widget.tmdbId,
      seasonNumber: widget.season,
      episodeNumber: widget.episode,
      progressSeconds: _lastProgressSeconds,
      durationSeconds: _lastDurationSeconds,
    );
  }

  Future<void> _markAsFinished() async {
    await _saveViewingProgress(completed: true);
    if (mounted) Navigator.pop(context);
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
    if (_provider == provider &&
        !_usingNativeStream &&
        !_isResolvingNativeStream) {
      return;
    }
    _nativeResolveToken++;
    _revealControls();
    setState(() {
      _provider = provider;
      _usingNativeStream = false;
      _isResolvingNativeStream = false;
      _isLoading = true;
      _loadError = null;
    });

    final url = _currentEmbedUrl;
    if (url.toLowerCase().contains('.m3u8')) {
      setState(() {
        _isLoading = false;
      });
    }
    if (url.isNotEmpty) {
      await _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url), headers: _mobileHeaders),
      );
    }
  }

  Future<void> _reloadCurrent() async {
    _revealControls();
    if (_usingNativeStream) {
      _nativeResolveToken++;
      setState(() {
        _nativeStreamUrl = null;
        _usingNativeStream = false;
        _isLoading = true;
        _loadError = null;
      });
      unawaited(_resolveNativeStream());
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    await _webViewController?.reload();
  }

  Future<void> _resolveNativeStream() async {
    final token = ++_nativeResolveToken;
    final directUrl = widget.directUrl?.trim();

    if (directUrl != null &&
        directUrl.isNotEmpty &&
        _isDirectPlayableUrl(directUrl)) {
      if (!mounted || token != _nativeResolveToken) return;
      setState(() {
        _nativeStreamUrl = directUrl;
        _usingNativeStream = true;
        _isResolvingNativeStream = false;
        _isLoading = false;
        _loadError = null;
      });
      return;
    }

    final tmdbId = widget.tmdbId?.trim();
    if (tmdbId == null || tmdbId.isEmpty) {
      if (!mounted || token != _nativeResolveToken) return;
      setState(() {
        _usingNativeStream = false;
        _isResolvingNativeStream = false;
        _isLoading = _currentEmbedUrl.isNotEmpty;
      });
      return;
    }

    setState(() {
      _isResolvingNativeStream = true;
      _loadError = null;
    });

    try {
      final streamUrl = await ApiService.getValidStreamUrl(
        tmdbId: tmdbId,
        url: directUrl,
        type: _normalizedMediaType,
        season: widget.season,
        episode: widget.episode,
      ).timeout(const Duration(seconds: 35));

      if (!mounted || token != _nativeResolveToken) return;

      if (streamUrl != null && streamUrl.isNotEmpty) {
        _promoteToNativeStream(streamUrl);
        return;
      }
    } catch (error) {
      debugPrint('Native stream resolution failed: $error');
    }

    if (!mounted || token != _nativeResolveToken) return;
    setState(() {
      _nativeStreamUrl = null;
      _usingNativeStream = false;
      _isResolvingNativeStream = false;
      _loadError = null;
    });
  }

  void _promoteToNativeStream(String url) {
    if (!mounted || !_isDirectPlayableUrl(url)) return;
    if (_usingNativeStream && _nativeStreamUrl == url) return;

    setState(() {
      _nativeStreamUrl = url;
      _usingNativeStream = true;
      _isResolvingNativeStream = false;
      _isLoading = false;
      _loadError = null;
    });
  }

  void _fallbackToEmbeddedPlayer() {
    if (!_usingNativeStream || !mounted) return;
    _nativeResolveToken++;
    setState(() {
      _nativeStreamUrl = null;
      _usingNativeStream = false;
      _isResolvingNativeStream = false;
      _isLoading = _currentEmbedUrl.isNotEmpty;
      _loadError = null;
    });
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _loadError != null) return;
      setState(() => _showControls = false);
    });
  }

  void _revealControls() {
    final wasHidden = !_showControls;
    if (!_showControls && mounted) {
      setState(() => _showControls = true);
    }
    if (wasHidden) {
      unawaited(_pauseVisibleVideo());
    }
    _scheduleControlsHide();
  }

  Future<void> _pauseVisibleVideo() async {
    try {
      await _webViewController?.evaluateJavascript(
        source: '''
          (() => {
            const videos = Array.from(document.querySelectorAll('video'));
            videos.forEach((video) => video.pause());
            return videos.length;
          })();
        ''',
      );
    } catch (_) {
      // Some providers isolate the player in a cross-origin iframe.
    }
  }

  Widget _buildProviderButton(EmbedProvider provider) {
    final selected = _provider == provider;
    final label = provider == EmbedProvider.embed ? 'Embed' : 'VidSrc VIP';

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
    final playbackUrl = _playbackUrl;
    final settings = context.watch<SettingsProvider>();

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _revealControls(),
            child: Stack(
              children: [
                if (playbackUrl.isNotEmpty)
                  HybridVideoPlayer(
                    key: ValueKey(playbackUrl),
                    videoUrl: playbackUrl,
                    title: widget.title,
                    headers: _headersForUrl(playbackUrl),
                    showSubtitles: settings.showSubtitles,
                    subtitleColor: settings.subtitleColor,
                    onNativePlaybackFailed: _fallbackToEmbeddedPlayer,
                    onNativeUrlFound: _promoteToNativeStream,
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      if (!mounted) return;
                      setState(() {
                        _showControls = true;
                        _isLoading = true;
                        _loadError = null;
                      });
                      _scheduleControlsHide();
                    },
                    onLoadStop: (controller, url) {
                      if (!mounted) return;
                      setState(() => _isLoading = false);
                      _scheduleControlsHide();
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
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${widget.title} - $_playbackLabel',
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
                              _buildProviderButton(EmbedProvider.embed),
                              const SizedBox(width: 8),
                              _buildProviderButton(EmbedProvider.vidSrcVip),
                              const SizedBox(width: 8),
                              if (_canPersistProgress) ...[
                                IconButton(
                                  tooltip: 'Marcar como visto',
                                  onPressed: _markAsFinished,
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              IconButton(
                                onPressed: _reloadCurrent,
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
      ),
    );
  }
}
