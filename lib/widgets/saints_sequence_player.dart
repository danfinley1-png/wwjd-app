import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/app_colors.dart';
import '../core/saint_media_url.dart';
import '../models/saint_video.dart';

/// Plays saint clips in order. URLs come from Firestore, never from bundled assets.
class SaintsSequencePlayer extends StatefulWidget {
  const SaintsSequencePlayer({
    super.key,
    required this.segments,
    this.autoPlay = false,
  });

  final List<SaintSegment> segments;
  final bool autoPlay;

  @override
  State<SaintsSequencePlayer> createState() => _SaintsSequencePlayerState();
}

class _SaintsSequencePlayerState extends State<SaintsSequencePlayer> {
  VideoPlayerController? _controller;
  int _index = 0;
  bool _loading = false;
  String? _error;
  bool _completed = false;

  List<SaintSegment> get _clips =>
      widget.segments.where((s) => s.hasVideo).toList();

  SaintSegment? get _current =>
      _index >= 0 && _index < _clips.length ? _clips[_index] : null;

  @override
  void initState() {
    super.initState();
    if (_clips.isNotEmpty) {
      _load(_index, play: widget.autoPlay);
    }
  }

  @override
  void didUpdateWidget(SaintsSequencePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrls = oldWidget.segments.map((s) => s.videoUrl).join('|');
    final newUrls = widget.segments.map((s) => s.videoUrl).join('|');
    if (oldUrls != newUrls) {
      _index = 0;
      _completed = false;
      if (_clips.isNotEmpty) {
        _load(0, play: widget.autoPlay);
      } else {
        _disposeController();
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _controller = null;
  }

  Future<void> _load(int index, {required bool play}) async {
    if (index < 0 || index >= _clips.length) return;
    setState(() {
      _index = index;
      _loading = true;
      _error = null;
      _completed = false;
    });
    _disposeController();
    final url = SaintMediaUrl.playbackUrl(_clips[index].videoUrl.trim());
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.addListener(_onTick);
    try {
      await controller.initialize();
      if (!mounted || _controller != controller) return;
      await controller.setLooping(false);
      if (play) await controller.play();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'This clip could not be played.';
      });
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;
    if (value.hasError && _error == null) {
      setState(() => _error = 'This clip could not be played.');
      return;
    }
    final duration = value.duration;
    if (duration > Duration.zero &&
        !value.isPlaying &&
        value.position >= duration - const Duration(milliseconds: 400) &&
        !_completed) {
      _advance();
    }
  }

  void _advance() {
    if (_index + 1 < _clips.length) {
      _load(_index + 1, play: true);
    } else {
      setState(() => _completed = true);
    }
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (_completed) {
        await _load(0, play: true);
        return;
      }
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_clips.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No clips uploaded yet.'),
      );
    }

    final current = _current;
    final controller = _controller;
    final initialized = controller?.value.isInitialized == true;
    final playing = controller?.value.isPlaying == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: initialized ? controller!.value.aspectRatio : 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (initialized) VideoPlayer(controller!),
                  if (_loading) const CircularProgressIndicator(color: Colors.white),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (initialized && current != null && current.caption.trim().isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: Text(
                          current.caption.trim(),
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          current == null
              ? ''
              : '${current.title} · ${_index + 1} of ${_clips.length}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous clip',
              onPressed: _index > 0 ? () => _load(_index - 1, play: true) : null,
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              tooltip: playing ? 'Pause' : 'Play',
              onPressed: initialized || _completed ? _togglePlay : null,
              icon: Icon(
                _completed
                    ? Icons.replay
                    : playing
                        ? Icons.pause_circle
                        : Icons.play_circle,
                color: AppColors.primaryMaroon,
                size: 40,
              ),
            ),
            IconButton(
              tooltip: 'Next clip',
              onPressed: _index + 1 < _clips.length
                  ? () => _load(_index + 1, play: true)
                  : null,
              icon: const Icon(Icons.skip_next),
            ),
            const Spacer(),
            if (initialized)
              Text(_format(controller!.value.position, controller.value.duration)),
          ],
        ),
        if (initialized)
          VideoProgressIndicator(
            controller!,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: AppColors.primaryMaroon,
              bufferedColor: AppColors.primaryMaroon.withValues(alpha: 0.3),
              backgroundColor: Colors.black12,
            ),
          ),
      ],
    );
  }

  static String _format(Duration position, Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    String mmss(Duration d) => '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
    return '${mmss(position)} / ${mmss(duration)}';
  }
}
