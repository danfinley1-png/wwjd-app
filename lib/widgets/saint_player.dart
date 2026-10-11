import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../core/responsive_layout.dart';
import '../core/saint_media_url.dart';
import '../core/saint_playback_errors.dart';
import '../models/saint_video.dart';
import 'saint_poster_image.dart';
import 'web/saint_web_video_stub.dart'
    if (dart.library.html) 'web/saint_web_video_web.dart';

/// Portrait-first saint video player (9:16 default; 16:9 on wide when available).
class SaintPlayer extends StatefulWidget {
  const SaintPlayer({
    super.key,
    required this.saint,
    this.startMuted = false,
    this.autoPlay = true,
    this.hero = false,
  });

  final SaintEntry saint;
  final bool startMuted;
  final bool autoPlay;

  /// Larger layout for feast-day hero on the calendar page.
  final bool hero;

  @override
  State<SaintPlayer> createState() => _SaintPlayerState();
}

class _SaintPlayerState extends State<SaintPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _showPoster = true;
  String? _error;
  bool _muted = false;

  /// Web: native HTML5 video (see [buildSaintWebVideo]).
  String? _webPlaybackUrl;
  List<String> _webSources = const [];
  int _webSourceIndex = 0;

  /// Avoid re-init on every layout tick; re-init when source set changes.
  String? _playbackSourceKey;

  static const double _wideBreakpoint = kDesktopBreakpoint;

  /// Stream proxy source when Firestore has no landscape download URL.
  static const String _storageSourcePrefix = 'storage:';

  @override
  void initState() {
    super.initState();
    _muted = widget.startMuted;
  }

  @override
  void didUpdateWidget(SaintPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saint.slug != widget.saint.slug ||
        oldWidget.saint.videoPortraitUrl != widget.saint.videoPortraitUrl ||
        oldWidget.saint.videoLandscapeUrl != widget.saint.videoLandscapeUrl) {
      _playbackSourceKey = null;
    }
  }

  void _ensurePlaybackForWidth(double layoutWidth) {
    final sources = _sourceUrlsForWidth(layoutWidth);
    final key = '${layoutWidth >= _wideBreakpoint}:${sources.join('|')}';
    if (key == _playbackSourceKey) return;
    _playbackSourceKey = key;
    debugPrint(
      'SaintPlayer layout=${layoutWidth.round()}px slug=${widget.saint.slug} '
      'sources=${sources.map(_sourceLabel).join(' → ')}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initPlayer(layoutWidth);
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  String? _landscapeSourceRef() {
    final url = widget.saint.videoLandscapeUrl?.trim();
    if (url != null && url.isNotEmpty && url != '...') return url;
    final inferred = widget.saint.inferredFeastLandscapeStoragePath;
    if (inferred != null) return '$_storageSourcePrefix$inferred';
    return null;
  }

  String _sourceLabel(String sourceRef) {
    if (sourceRef.startsWith(_storageSourcePrefix)) {
      return sourceRef.substring(_storageSourcePrefix.length);
    }
    return SaintMediaUrl.storagePathFromDownloadUrl(sourceRef) ?? sourceRef;
  }

  String _resolvePlaybackUrl(String sourceRef) {
    if (sourceRef.startsWith(_storageSourcePrefix)) {
      return SaintMediaUrl.streamUrlForStoragePath(
        sourceRef.substring(_storageSourcePrefix.length),
      );
    }
    // Web iframe: direct Storage URL (poster already uses it). Avoids proxy full-GET limits on large MP4s.
    if (kIsWeb) return sourceRef.trim();
    return SaintMediaUrl.playbackUrl(sourceRef);
  }

  List<String> _sourceUrlsForWidth(double width) {
    final portrait = widget.saint.videoPortraitUrl?.trim();
    final landscapeRef = _landscapeSourceRef();
    final wide = width >= _wideBreakpoint && landscapeRef != null;

    if (wide && landscapeRef != null) {
      if (portrait != null && portrait.isNotEmpty) {
        return [landscapeRef, portrait];
      }
      return [landscapeRef];
    }
    if (portrait != null && portrait.isNotEmpty) return [portrait];
    if (landscapeRef != null) return [landscapeRef];
    return const [];
  }

  double _aspectRatioForWidth(double width) {
    if (width >= _wideBreakpoint && _landscapeSourceRef() != null) {
      return 16 / 9;
    }
    return 9 / 16;
  }

  void _logPlayerState(VideoPlayerValue value, String label, {String? url}) {
    debugPrint(
      'SaintPlayer [$label] slug=${widget.saint.slug} '
      'url=${url ?? ""} '
      'initialized=${value.isInitialized} '
      'hasError=${value.hasError} '
      'isPlaying=${value.isPlaying} '
      'size=${value.size.width}x${value.size.height} '
      'errorDescription=${value.errorDescription ?? "(none)"}',
    );
  }

  Future<void> _initPlayer([double? layoutWidth]) async {
    final width = layoutWidth ?? MediaQuery.sizeOf(context).width;
    final sources = _sourceUrlsForWidth(width);
    if (sources.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Video is not available yet.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _showPoster = true;
    });

    _controller?.removeListener(_onVideoUpdate);
    await _controller?.dispose();
    _controller = null;

    if (kIsWeb) {
      await _initWebPlayer(sources);
      return;
    }

    Object? lastError;
    String? lastDesc;
    String? lastPlaybackUrl;

    for (final sourceUrl in sources) {
      final playbackUrl = _resolvePlaybackUrl(sourceUrl);
      lastPlaybackUrl = playbackUrl;
      debugPrint(
        'SaintPlayer trying source=${_sourceLabel(sourceUrl)} '
        'playbackUrl=$playbackUrl',
      );

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(playbackUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      _controller = controller;
      controller.addListener(_onVideoUpdate);

      try {
        await controller.initialize();
        _logPlayerState(controller.value, 'after initialize', url: playbackUrl);

        if (controller.value.hasError) {
          lastDesc = controller.value.errorDescription;
          lastError = Exception(lastDesc ?? 'hasError after initialize');
          await controller.dispose();
          _controller = null;
          continue;
        }

        await controller.setLooping(false);
        final volume = (widget.autoPlay && kIsWeb) || _muted ? 0.0 : 1.0;
        if (widget.autoPlay && kIsWeb) _muted = true;
        await controller.setVolume(volume);

        if (widget.autoPlay) {
          try {
            await controller.play();
            _logPlayerState(controller.value, 'after play', url: playbackUrl);
          } catch (e) {
            debugPrint('SaintPlayer autoplay blocked (non-fatal): $e');
          }
        }

        if (controller.value.hasError) {
          lastDesc = controller.value.errorDescription;
          lastError = Exception(lastDesc ?? 'hasError after play');
          await controller.dispose();
          _controller = null;
          continue;
        }

        if (!mounted) return;
        setState(() => _loading = false);
        return;
      } catch (e, st) {
        lastError = e;
        lastDesc = _controller?.value.errorDescription;
        debugPrint(
          'SaintPlayer init failed ($playbackUrl): $e\n$st '
          'hasError=${_controller?.value.hasError} '
          'errorDescription=${_controller?.value.errorDescription}',
        );
        await _controller?.dispose();
        _controller = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = SaintPlaybackErrors.messageFor(
        lastError,
        errorDescription: lastDesc,
      );
      debugPrint(
        'SaintPlayer all sources failed slug=${widget.saint.slug} '
        'lastUrl=$lastPlaybackUrl lastDesc=$lastDesc',
      );
    });
  }

  Future<void> _initWebPlayer(List<String> sources) async {
    _webSources = sources;
    _webSourceIndex = 0;
    final playbackUrl = _resolvePlaybackUrl(sources.first);
    debugPrint(
      'SaintPlayer web trying source=${_sourceLabel(sources.first)} '
      'playbackUrl=$playbackUrl',
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = null;
      _showPoster = true;
      _webPlaybackUrl = playbackUrl;
    });
  }

  void _onWebVideoError(String message) {
    debugPrint('SaintPlayer web error: $message');
    if (_webSourceIndex + 1 < _webSources.length) {
      _webSourceIndex++;
      final next = _webSources[_webSourceIndex];
      final playbackUrl = _resolvePlaybackUrl(next);
      debugPrint('SaintPlayer web fallback to $playbackUrl');
      if (!mounted) return;
      setState(() {
        _error = null;
        _webPlaybackUrl = playbackUrl;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _error = SaintPlaybackErrors.messageFor(
        Exception(message),
        errorDescription: message,
      );
    });
  }

  void _onVideoUpdate() {
    final controller = _controller;
    if (controller == null) return;

    final value = controller.value;
    if (value.hasError && _error == null) {
      _logPlayerState(value, 'runtime error');
      setState(() => _error = SaintPlaybackErrors.messageFor(
            null,
            errorDescription: value.errorDescription,
          ));
      return;
    }

    if (!value.isInitialized) return;
    if (_showPoster && value.position > Duration.zero) {
      setState(() => _showPoster = false);
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  Future<void> _openStreamInBrowser() async {
    final url = _webPlaybackUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;

    if (!controller.value.isInitialized) {
      await _initPlayer();
      return;
    }

    if (controller.value.hasError) {
      setState(() => _error = null);
      await _initPlayer();
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (kIsWeb && controller.value.volume == 0) {
        _muted = false;
        await controller.setVolume(1);
      }
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = widget.hero ? 560.0 : 420.0;
    final posterUrl = widget.saint.posterPortraitUrl?.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        _ensurePlaybackForWidth(width);
        final aspect = _aspectRatioForWidth(width);

        return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: AspectRatio(
            aspectRatio: aspect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    if (kIsWeb &&
                        _webPlaybackUrl != null &&
                        _error == null)
                      buildSaintWebVideo(
                        key: ValueKey(_webPlaybackUrl),
                        url: _webPlaybackUrl!,
                        autoPlay: widget.autoPlay,
                        startMuted: widget.startMuted || widget.autoPlay,
                        onError: _onWebVideoError,
                        onPlaying: () {
                          if (mounted && _showPoster) {
                            setState(() => _showPoster = false);
                          }
                        },
                      ),
                    if (!kIsWeb &&
                        _controller?.value.isInitialized == true &&
                        _controller!.value.hasError != true)
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    if (_showPoster &&
                        posterUrl != null &&
                        posterUrl.isNotEmpty)
                      Positioned.fill(
                        child: SaintPosterImage(
                          url: posterUrl,
                          fit: BoxFit.contain,
                          saintLabel: widget.saint.name,
                        ),
                      ),
                    if (_loading)
                      const CircularProgressIndicator(color: Colors.white70),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            if (kIsWeb && _webPlaybackUrl != null) ...[
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _openStreamInBrowser,
                                icon: const Icon(Icons.open_in_browser),
                                label: const Text('Open video in browser'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (!_loading && !kIsWeb)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _muted ? 'Unmute' : 'Mute',
                              onPressed:
                                  _controller?.value.isInitialized == true
                                      ? _toggleMute
                                      : null,
                              color: Colors.white,
                              icon: Icon(
                                _muted ? Icons.volume_off : Icons.volume_up,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Play / pause',
                              onPressed: _togglePlay,
                              color: Colors.white,
                              icon: Icon(
                                _controller?.value.isPlaying == true
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                              ),
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
        if (width >= _wideBreakpoint && _landscapeSourceRef() != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Wide layout: landscape video when available.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
      },
    );
  }
}
