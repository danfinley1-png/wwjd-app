import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';

import '../core/saints/saint_url_debug.dart';
import 'web/saint_poster_image_stub.dart'
    if (dart.library.html) 'web/saint_poster_image_web.dart';

/// Feast poster from Firestore [posterPortraitUrl] (Firebase Storage token URL).
class SaintPosterImage extends StatelessWidget {
  const SaintPosterImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.saintLabel,
  });

  final String url;
  final BoxFit fit;
  final String? saintLabel;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (!SaintUrlDebug.isUsableUrl(trimmed)) {
      if (kDebugMode && trimmed.isNotEmpty) {
        debugPrint(
          'SaintPosterImage skipped invalid url for ${saintLabel ?? "?"}: '
          '${SaintUrlDebug.describe('poster', trimmed)}',
        );
      }
      return const SizedBox.shrink();
    }

    if (kIsWeb) {
      return KeyedSubtree(
        key: ValueKey(trimmed),
        child: buildSaintPosterImage(url: trimmed, fit: fit),
      );
    }

    return Image.network(
      trimmed,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          'SaintPosterImage failed saint=${saintLabel ?? "?"} error=$error',
        );
        return const SizedBox.shrink();
      },
    );
  }
}
