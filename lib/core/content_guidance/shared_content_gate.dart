import 'package:flutter/material.dart';

import 'content_guidance_dialogs.dart';
import 'content_guidance_logger.dart';
import 'content_guidance_models.dart';
import 'shared_content_processor.dart';

/// UI + processing entry point for shared content before publication.
class SharedContentGate {
  SharedContentGate({SharedContentProcessor? processor})
      : _processor = processor ?? SharedContentProcessor();

  final SharedContentProcessor _processor;

  /// Processes [input], shows a review dialog when revisions are needed,
  /// and returns revised fields or null if the user cancels.
  Future<SharedContentGateResult?> prepare(
    BuildContext context, {
    required SharedContentInput input,
    required SharedContentChannel channel,
  }) async {
    final result = _processor.process(input);
    if (!result.needsReview) {
      return SharedContentGateResult(input: result.revised);
    }

    ContentGuidanceLogger.logSharedAdjustment(
      channel: channel,
      adjustments: result.adjustments,
    );

    if (!context.mounted) return null;
    final revised = await SharedContentReviewDialog.show(context, result);
    if (revised == null) return null;

    return SharedContentGateResult(
      input: revised,
      requiresAnonymousSharing: result.requiresAnonymousSharing,
    );
  }

  /// Service-layer safety net — applies revisions without UI.
  SharedContentGateResult processSilently(
    SharedContentInput input, {
    SharedContentChannel channel = SharedContentChannel.walkTogether,
  }) {
    final result = _processor.process(input);
    if (result.wasModified) {
      ContentGuidanceLogger.logSharedAdjustment(
        channel: channel,
        adjustments: result.adjustments,
      );
    }
    return SharedContentGateResult(
      input: result.revised,
      requiresAnonymousSharing: result.requiresAnonymousSharing,
    );
  }
}

/// App-wide default gate instance.
final sharedContentGate = SharedContentGate();
