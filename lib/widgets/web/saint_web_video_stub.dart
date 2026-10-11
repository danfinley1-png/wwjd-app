import 'package:flutter/material.dart';

/// Non-web: saint playback uses [VideoPlayerController] in [SaintPlayer].
Widget buildSaintWebVideo({
  Key? key,
  required String url,
  required bool autoPlay,
  required bool startMuted,
  required void Function(String message)? onError,
  required void Function()? onPlaying,
}) {
  return const SizedBox.shrink();
}
