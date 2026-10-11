import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _saintVideoViewId = 0;

/// Embeds the same stream URL that works in a browser tab (iframe native player).
class SaintWebVideo extends StatefulWidget {
  const SaintWebVideo({
    super.key,
    required this.url,
    required this.autoPlay,
    required this.startMuted,
    this.onError,
    this.onPlaying,
  });

  final String url;
  final bool autoPlay;
  final bool startMuted;
  final void Function(String message)? onError;
  final VoidCallback? onPlaying;

  @override
  State<SaintWebVideo> createState() => SaintWebVideoState();
}

class SaintWebVideoState extends State<SaintWebVideo> {
  late final String _viewType = 'wwjd-saint-video-${_saintVideoViewId++}';

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  void _registerView() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final wrapper = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000000'
        ..style.overflow = 'hidden';

      // Same URL as "open in browser" — avoids HtmlElementView <video> quirks on iOS PWA.
      final iframe = html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..setAttribute(
          'allow',
          'autoplay; fullscreen; encrypted-media',
        );

      iframe.onLoad.listen((_) => widget.onPlaying?.call());

      iframe.onError.listen((_) {
        widget.onError?.call('Could not load video frame.');
      });

      wrapper.children.add(iframe);
      return wrapper;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

Widget buildSaintWebVideo({
  Key? key,
  required String url,
  required bool autoPlay,
  required bool startMuted,
  required void Function(String message)? onError,
  required void Function()? onPlaying,
}) {
  return SaintWebVideo(
    key: key,
    url: url,
    autoPlay: autoPlay,
    startMuted: startMuted,
    onError: onError,
    onPlaying: onPlaying,
  );
}
