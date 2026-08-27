import 'package:flutter/foundation.dart';

import 'content_guidance_models.dart';

/// Logs guidance metadata without retaining explicit or personal content.
class ContentGuidanceLogger {
  ContentGuidanceLogger._();

  static void logSharedAdjustment({
    required SharedContentChannel channel,
    required List<ContentAdjustment> adjustments,
  }) {
    if (adjustments.isEmpty) return;

    final kinds = adjustments.map((a) => a.kind.name).toSet().join(', ');
    final fields = adjustments.map((a) => a.field.name).toSet().join(', ');

    debugPrint(
      'ContentGuidance[${channel.name}]: adjusted fields=$fields kinds=$kinds '
      'count=${adjustments.length}',
    );
  }

  static void logPrivateSuggestionOffered() {
    debugPrint('ContentGuidance[private]: optional rephrase suggestion offered');
  }

  static void logPrivateSuggestionAccepted({required bool accepted}) {
    debugPrint(
      'ContentGuidance[private]: suggestion ${accepted ? 'accepted' : 'declined'}',
    );
  }
}
