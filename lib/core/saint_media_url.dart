import 'package:flutter/foundation.dart' show kIsWeb;

import 'config.dart';

/// Resolves Firestore Storage download URLs to a URL [video_player] can use on web.
class SaintMediaUrl {
  SaintMediaUrl._();

  static final RegExp _firebaseObjectPath = RegExp(
    r'^/v0/b/[^/]+/o/(.+)$',
  );

  /// Storage object path from a Firebase download URL, or null if not Firebase Storage.
  static String? storagePathFromDownloadUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (!uri.host.contains('firebasestorage.googleapis.com')) return null;

    final match = _firebaseObjectPath.firstMatch(uri.path);
    if (match == null) return null;
    return Uri.decodeComponent(match.group(1)!);
  }

  /// Same-origin / Cloud Function stream for a Storage object path (no token required).
  static String streamUrlForStoragePath(String objectPath) {
    final encodedPath = Uri.encodeComponent(objectPath.trim());
    if (kIsWeb) {
      return '${AppConfig.streamSaintVideoApiUrl}?path=$encodedPath';
    }
    return '${AppConfig.streamSaintVideoFunctionUrl}?path=$encodedPath';
  }

  /// Playback URL: stream proxy when Storage path is known (web + native); else direct URL.
  static String playbackUrl(String firestoreDownloadUrl) {
    final trimmed = firestoreDownloadUrl.trim();
    if (trimmed.isEmpty) return trimmed;

    final objectPath = storagePathFromDownloadUrl(trimmed);
    if (objectPath == null) return trimmed;

    return streamUrlForStoragePath(objectPath);
  }
}
