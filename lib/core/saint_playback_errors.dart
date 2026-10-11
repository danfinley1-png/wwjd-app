/// User-facing copy when [video_player] fails on web.
class SaintPlaybackErrors {
  SaintPlaybackErrors._();

  static const int _maxUserDetailLength = 280;

  /// Maps [VideoPlayerController.value.errorDescription] and init exceptions.
  static String messageFor(
    Object? error, {
    String? errorDescription,
    bool includeTechnicalDetail = true,
  }) {
    final desc = (errorDescription ?? '').trim();
    final errStr = error?.toString().trim() ?? '';
    final blob = '$errStr $desc'.toLowerCase();

    if (_isHevcOrH265(blob)) {
      return 'This file looks like HEVC (H.265), which many browsers cannot play. '
          'Re-export as H.264 + AAC MP4 and re-upload (see tool/reencode_saint_videos.md).';
    }

    if (blob.contains('media_err_network') ||
        blob.contains('network') && blob.contains('failed')) {
      return 'Network error while loading the video. Check your connection and try again.';
    }

    if (blob.contains('media_err_src_not_supported') ||
        blob.contains('not supported by your browser')) {
      return 'Your browser could not play this MP4. Confirm the upload finished, '
          'use H.264 (yuv420p) + AAC with faststart, then hard-refresh.';
    }

    if (includeTechnicalDetail) {
      if (desc.isNotEmpty) {
        return 'Playback failed: ${_truncate(desc)}';
      }
      if (errStr.isNotEmpty && !errStr.startsWith('Exception: Exception:')) {
        return 'Playback failed: ${_truncate(errStr)}';
      }
    }

    return 'This video could not be played in the app player. '
        'Use Open video in browser below, or refresh and try again.';
  }

  static bool _isHevcOrH265(String blob) {
    return blob.contains('hevc') ||
        blob.contains('h265') ||
        blob.contains('h.265');
  }

  static String _truncate(String text) {
    if (text.length <= _maxUserDetailLength) return text;
    return '${text.substring(0, _maxUserDetailLength - 1)}…';
  }
}
