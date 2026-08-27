import 'package:flutter/material.dart';

import '../core/share_content.dart';
import 'unified_share_flow.dart';

/// Gift / Kingdom Challenge share entry point (uses unified flow).
class GiftShareDialog {
  GiftShareDialog._();

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    String? linkedActivityId,
    String? linkedPrayerId,
  }) {
    return UnifiedShareFlow.show(
      context,
      content: ShareContent.gift(
        title: title,
        description: description,
        linkedActivityId: linkedActivityId,
        linkedPrayerId: linkedPrayerId,
      ),
    );
  }
}
