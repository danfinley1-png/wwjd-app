import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _saintPosterViewId = 0;

/// HTML [img] for Firebase Storage posters (avoids Flutter web Image.network CORS).
Widget buildSaintPosterImage({
  required String url,
  required BoxFit fit,
}) {
  return _SaintPosterHtml(url: url, fit: fit);
}

class _SaintPosterHtml extends StatefulWidget {
  const _SaintPosterHtml({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  State<_SaintPosterHtml> createState() => _SaintPosterHtmlState();
}

class _SaintPosterHtmlState extends State<_SaintPosterHtml> {
  late final String _viewType = 'wwjd-saint-poster-${_saintPosterViewId++}';

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final objectFit = widget.fit == BoxFit.cover ? 'cover' : 'contain';
      final wrapper = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden'
        ..style.backgroundColor = '#000000';

      final img = html.ImageElement()
        ..src = widget.url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = objectFit
        ..style.display = 'block';

      wrapper.children.add(img);
      return wrapper;
    });
  }

  @override
  void didUpdateWidget(_SaintPosterHtml oldWidget) {
    super.didUpdateWidget(oldWidget);
    // View factory captures initial url; rebuild with new key from parent if url changes.
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
