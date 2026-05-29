import 'dart:async';
import 'dart:convert';
import 'dart:ui';

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
  final String? subtitleUrl;
  final String subtitleLanguage;
  final String subtitleLabel;

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
    this.subtitleUrl,
    this.subtitleLanguage = 'es-419',
    this.subtitleLabel = 'Espanol Latino',
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
  String? _nativeSourceUrl;
  String? _nativeSubtitleUrl;
  String? _nativeSubtitleLanguage;
  String? _nativeSubtitleLabel;
  bool _isResolvingNativeStream = true;
  bool _usingNativeStream = false;
  bool _nativeModeRequested = true;
  int _nativeResolveToken = 0;
  bool _showSettingsPanel = false;

  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  String get _normalizedMediaType {
    final type = widget.type.toLowerCase();
    return type.contains('serie') || type.contains('tv') ? 'tv' : 'movie';
  }

  Map<String, String> _headersForUrl(String url, {String? sourceUrl}) {
    final lower = url.toLowerCase();
    if (_isDirectPlayableUrl(lower)) {
      final sourceUri = Uri.tryParse(sourceUrl ?? '');
      final sourceOrigin = sourceUri?.origin;
      return {
        'User-Agent': _desktopUserAgent,
        ...?sourceOrigin == null
            ? null
            : {'Referer': '$sourceOrigin/', 'Origin': sourceOrigin},
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
        return Uri.https('vidrock.net', path, {
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
    if (_nativeModeRequested && _isResolvingNativeStream) {
      return '';
    }
    return _currentEmbedUrl;
  }

  String get _playbackLabel {
    return _usingNativeStream || _nativeModeRequested
        ? 'Nativo'
        : _providerName;
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

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final pref = settings.preferredServer;
    if (pref == 'embed') {
      _provider = EmbedProvider.embed;
      _nativeModeRequested = false;
      _usingNativeStream = false;
      _isResolvingNativeStream = false;
      _isLoading = _currentEmbedUrl.isNotEmpty;
    } else if (pref == 'vidsrc_vip') {
      _provider = EmbedProvider.vidSrcVip;
      _nativeModeRequested = false;
      _usingNativeStream = false;
      _isResolvingNativeStream = false;
      _isLoading = _currentEmbedUrl.isNotEmpty;
    } else {
      _provider = EmbedProvider.embed;
      _nativeModeRequested = true;
      _isResolvingNativeStream = true;
      _isLoading = true;
    }

    if (_nativeModeRequested) {
      unawaited(_resolveNativeStream());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_currentEmbedUrl.isNotEmpty) {
          _webViewController?.loadUrl(
            urlRequest: URLRequest(
              url: WebUri(_currentEmbedUrl),
              headers: _mobileHeaders,
            ),
          );
        }
      });
    }
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
      _nativeStreamUrl = null;
      _nativeSourceUrl = null;
      _nativeSubtitleUrl = null;
      _nativeSubtitleLanguage = null;
      _nativeSubtitleLabel = null;
      _usingNativeStream = false;
      _nativeModeRequested = false;
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
      _reloadNativePlayer();
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    await _webViewController?.reload();
  }

  void _reloadNativePlayer() {
    _nativeResolveToken++;
    _revealControls();
    final activeEmbedUrl = !_usingNativeStream && !_nativeModeRequested
        ? _currentEmbedUrl
        : null;
      setState(() {
        _nativeStreamUrl = null;
        _nativeSourceUrl = null;
        _nativeSubtitleUrl = null;
        _nativeSubtitleLanguage = null;
        _nativeSubtitleLabel = null;
        _usingNativeStream = false;
      _nativeModeRequested = true;
      _isResolvingNativeStream = true;
      _isLoading = true;
      _loadError = null;
    });
    unawaited(_resolveNativeStream(preferredEmbedUrl: activeEmbedUrl));
  }

  Future<void> _resolveNativeStream({String? preferredEmbedUrl}) async {
    final token = ++_nativeResolveToken;
    final directUrl = widget.directUrl?.trim();

    if (directUrl != null &&
        directUrl.isNotEmpty &&
        _isDirectPlayableUrl(directUrl)) {
      if (!mounted || token != _nativeResolveToken) return;
      setState(() {
        _nativeStreamUrl = directUrl;
        _nativeSourceUrl = null;
        _nativeSubtitleUrl = null;
        _nativeSubtitleLanguage = null;
        _nativeSubtitleLabel = null;
        _usingNativeStream = true;
        _nativeModeRequested = true;
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
        _nativeModeRequested = false;
        _usingNativeStream = false;
        _isResolvingNativeStream = false;
        _isLoading = _currentEmbedUrl.isNotEmpty;
      });
      return;
    }

    setState(() {
      _nativeModeRequested = true;
      _isResolvingNativeStream = true;
      _isLoading = true;
      _loadError = null;
    });

    final activeEmbedUrl = preferredEmbedUrl?.trim();

    if (activeEmbedUrl != null && activeEmbedUrl.isNotEmpty) {
      try {
        final streamCandidate = await ApiService.getValidStreamCandidate(
          url: activeEmbedUrl,
          type: _normalizedMediaType,
          season: widget.season,
          episode: widget.episode,
        ).timeout(const Duration(seconds: 45));

        if (!mounted || token != _nativeResolveToken) return;

        if (streamCandidate != null && streamCandidate.url.isNotEmpty) {
          _promoteToNativeCandidate(streamCandidate, sourceUrl: activeEmbedUrl);
          return;
        }
      } catch (error) {
        debugPrint('Active embed extraction failed: $error');
      }
    }

    try {
      final streamCandidate = await ApiService.getValidStreamCandidate(
        tmdbId: tmdbId,
        url: directUrl,
        type: _normalizedMediaType,
        season: widget.season,
        episode: widget.episode,
      ).timeout(const Duration(seconds: 35));

      if (!mounted || token != _nativeResolveToken) return;

      if (streamCandidate != null && streamCandidate.url.isNotEmpty) {
        _promoteToNativeCandidate(streamCandidate);
        return;
      }
    } catch (error) {
      debugPrint('Native stream resolution failed: $error');
    }

    if (!mounted || token != _nativeResolveToken) return;
    setState(() {
      _nativeStreamUrl = null;
      _nativeSourceUrl = null;
      _nativeSubtitleUrl = null;
      _nativeSubtitleLanguage = null;
      _nativeSubtitleLabel = null;
      _usingNativeStream = false;
      _nativeModeRequested = false;
      _isResolvingNativeStream = false;
      _isLoading = _currentEmbedUrl.isNotEmpty;
      _loadError = null;
    });
  }

  void _promoteToNativeStream(String url, {String? sourceUrl}) {
    if (!mounted || !_isDirectPlayableUrl(url)) return;
    if (_usingNativeStream && _nativeStreamUrl == url) return;

    setState(() {
      _nativeStreamUrl = url;
      _nativeSourceUrl = sourceUrl;
      _nativeSubtitleUrl = null;
      _nativeSubtitleLanguage = null;
      _nativeSubtitleLabel = null;
      _usingNativeStream = true;
      _nativeModeRequested = true;
      _isResolvingNativeStream = false;
      _isLoading = false;
      _loadError = null;
    });
  }

  void _promoteToNativeCandidate(StreamPlaybackCandidate candidate, {String? sourceUrl}) {
    if (!mounted || !_isDirectPlayableUrl(candidate.url)) return;
    if (_usingNativeStream && _nativeStreamUrl == candidate.url) return;

    setState(() {
      _nativeStreamUrl = candidate.url;
      _nativeSourceUrl = sourceUrl;
      _nativeSubtitleUrl = candidate.subtitleUrl;
      _nativeSubtitleLanguage = candidate.subtitleLanguage;
      _nativeSubtitleLabel = candidate.subtitleLabel;
      _usingNativeStream = true;
      _nativeModeRequested = true;
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
      _nativeSourceUrl = null;
      _nativeSubtitleUrl = null;
      _nativeSubtitleLanguage = null;
      _nativeSubtitleLabel = null;
      _usingNativeStream = false;
      _nativeModeRequested = false;
      _isResolvingNativeStream = false;
      _isLoading = _currentEmbedUrl.isNotEmpty;
      _loadError = null;
    });
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    if (_showSettingsPanel) return;
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

  Widget _buildSettingsHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 12.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildServerOption({
    required String title,
    required String subtitle,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: active ? const Color(0xFF00D46A) : Colors.white,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (active)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF00D46A),
                size: 20,
              )
            else
              const Icon(
                Icons.circle_outlined,
                color: Colors.white24,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockOption({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
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
                    headers: _headersForUrl(
                      playbackUrl,
                      sourceUrl: _usingNativeStream ? _nativeSourceUrl : null,
                    ),
                    showSubtitles: settings.showSubtitles,
                    subtitleColor: settings.subtitleColor,
                    subtitleUrl: _nativeSubtitleUrl ?? widget.subtitleUrl,
                    subtitleLanguage: _nativeSubtitleLanguage ?? widget.subtitleLanguage,
                    subtitleLabel: _nativeSubtitleLabel ?? widget.subtitleLabel,
                    onNativePlaybackFailed: _fallbackToEmbeddedPlayer,
                    onNativeUrlFound: (url) {
                      _promoteToNativeStream(url, sourceUrl: _currentEmbedUrl);
                    },
                    allowNativeUrlPromotion: _nativeModeRequested,
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
                  Center(
                    child: _isResolvingNativeStream
                        ? const CircularProgressIndicator(
                            color: Color(0xFF00D46A),
                          )
                        : const Text(
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
                
                // Botón de Ajustes en la esquina inferior derecha
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: IconButton(
                        icon: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () {
                          setState(() {
                            _showSettingsPanel = true;
                            _controlsTimer?.cancel();
                          });
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.68),
                          padding: const EdgeInsets.all(12),
                          shape: const CircleBorder(),
                        ),
                      ),
                    ),
                  ),
                ),

                // Fondo oscuro semi-transparente para cerrar el panel al pulsar fuera
                if (_showSettingsPanel)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _showSettingsPanel = false;
                          _scheduleControlsHide();
                        });
                      },
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ),

                // Panel lateral de Ajustes deslizable (Slide-in)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  top: 0,
                  bottom: 0,
                  right: _showSettingsPanel ? 0 : -320,
                  width: 320,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.82),
                          border: const Border(
                            left: BorderSide(color: Colors.white12, width: 1),
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Cabecera del Panel
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.settings, color: Color(0xFF00D46A)),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Ajustes de Video',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white70),
                                      onPressed: () {
                                        setState(() {
                                          _showSettingsPanel = false;
                                          _scheduleControlsHide();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(color: Colors.white12, height: 1),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  children: [
                                    // Sección de Servidor
                                    _buildSettingsHeader('Servidor / Fuente'),
                                    _buildServerOption(
                                      title: 'Nativo (Recomendado)',
                                      subtitle: 'Reproductor fluido y nativo',
                                      active: _usingNativeStream || _nativeModeRequested,
                                      onTap: () async {
                                        _reloadNativePlayer();
                                        await settings.updateSettings(newPreferredServer: 'nativo');
                                      },
                                    ),
                                    _buildServerOption(
                                      title: 'Embed',
                                      subtitle: 'Servidor embed estándar',
                                      active: !_nativeModeRequested && _provider == EmbedProvider.embed,
                                      onTap: () async {
                                        await _reloadProvider(EmbedProvider.embed);
                                        await settings.updateSettings(newPreferredServer: 'embed');
                                      },
                                    ),
                                    _buildServerOption(
                                      title: 'VidSrc VIP',
                                      subtitle: 'Servidor rápido alternativo',
                                      active: !_nativeModeRequested && _provider == EmbedProvider.vidSrcVip,
                                      onTap: () async {
                                        await _reloadProvider(EmbedProvider.vidSrcVip);
                                        await settings.updateSettings(newPreferredServer: 'vidsrc_vip');
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(color: Colors.white10),
                                    
                                    // Sección de Subtítulos
                                    _buildSettingsHeader('Subtítulos'),
                                    SwitchListTile(
                                      value: settings.showSubtitles,
                                      activeThumbColor: const Color(0xFF00D46A),
                                      title: const Text(
                                        'Activar Subtítulos',
                                        style: TextStyle(color: Colors.white, fontSize: 14),
                                      ),
                                      onChanged: (val) {
                                        settings.updateSettings(newShowSubtitles: val);
                                      },
                                    ),
                                    
                                    const SizedBox(height: 12),
                                    const Divider(color: Colors.white10),

                                    // Sección de Calidad y Velocidad
                                    _buildSettingsHeader('Calidad (Escalable)'),
                                    _buildMockOption(
                                      icon: Icons.high_quality,
                                      title: 'Calidad de Video',
                                      value: 'Automática (1080p)',
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(color: Colors.white10),

                                    _buildSettingsHeader('Velocidad (Escalable)'),
                                    _buildMockOption(
                                      icon: Icons.speed,
                                      title: 'Velocidad de reproducción',
                                      value: 'Normal (1.0x)',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
