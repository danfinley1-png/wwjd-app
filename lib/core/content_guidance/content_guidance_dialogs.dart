import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../responsive_layout.dart';
import 'content_guidance_messages.dart';
import 'content_guidance_models.dart';

/// Optional pastoral rephrase before a private question is sent.
class PrivateRephraseDialog {
  PrivateRephraseDialog._();

  static Future<String?> show(
    BuildContext context,
    PrivateContentSuggestion suggestion,
  ) async {
    if (!suggestion.hasSuggestion) return suggestion.original;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('A gentle suggestion'),
        content: SizedBox(
          width: responsiveDialogMaxWidth(ctx),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  suggestion.pastoralNote,
                  style: const TextStyle(height: 1.45),
                ),
                const SizedBox(height: 16),
                _LabeledBlock(
                  label: 'Your words',
                  text: suggestion.original,
                  muted: true,
                ),
                const SizedBox(height: 12),
                _LabeledBlock(
                  label: 'Optional framing',
                  text: suggestion.suggestedRephrase!,
                  muted: false,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, suggestion.original),
            child: const Text('Continue with my words'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, suggestion.suggestedRephrase),
            child: const Text('Use suggested framing'),
          ),
        ],
      ),
    );
  }
}

class SharedContentReviewDialog {
  SharedContentReviewDialog._();

  /// Returns revised input, or null if the user cancels sharing.
  static Future<SharedContentInput?> show(
    BuildContext context,
    SharedContentResult result,
  ) async {
    if (!result.needsReview) return result.revised;

    final kinds = result.adjustments.map((a) => a.kind).toSet();

    return showDialog<SharedContentInput>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(ContentGuidanceMessages.sharedReviewTitle),
        content: SizedBox(
          width: responsiveDialogMaxWidth(ctx),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  ContentGuidanceMessages.sharedReviewIntro,
                  style: TextStyle(height: 1.45),
                ),
                if (result.requiresAnonymousSharing) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        size: 18,
                        color: AppColors.primaryMaroon.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          ContentGuidanceMessages.anonymousRequiredNote,
                          style: TextStyle(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                for (final kind in kinds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.volunteer_activism_outlined,
                          size: 18,
                          color: AppColors.primaryMaroon.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ContentGuidanceMessages.adjustmentBullet(kind),
                            style: const TextStyle(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                ..._fieldComparisons(result),
                const SizedBox(height: 12),
                const Text(
                  ContentGuidanceMessages.sharedReviewFooter,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, result.revised),
            child: const Text('Share revised version'),
          ),
        ],
      ),
    );
  }

  static List<Widget> _fieldComparisons(SharedContentResult result) {
    final widgets = <Widget>[];
    for (final entry in result.original.nonEmptyFields) {
      final revisedValue = _fieldValue(result.revised, entry.key);
      if (revisedValue == null || revisedValue == entry.value) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                entry.key.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              _LabeledBlock(label: 'Original', text: entry.value, muted: true),
              const SizedBox(height: 6),
              _LabeledBlock(label: 'Shared version', text: revisedValue, muted: false),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  static String? _fieldValue(SharedContentInput input, ContentField field) {
    switch (field) {
      case ContentField.question:
        return input.question;
      case ContentField.response:
        return input.response;
      case ContentField.title:
        return input.title;
      case ContentField.personalNote:
        return input.personalNote;
      case ContentField.description:
        return input.description;
    }
  }
}

class _LabeledBlock extends StatelessWidget {
  const _LabeledBlock({
    required this.label,
    required this.text,
    required this.muted,
  });

  final String label;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: muted ? Colors.grey.shade100 : AppColors.parchmentDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: muted ? Colors.grey.shade300 : AppColors.gold.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }
}
