import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../core/gift_activity_link.dart';
import '../core/providers/app_providers.dart';
import '../models/reflection_source.dart';
import '../models/reflection_thread.dart';
import '../models/walk_together_journey.dart';
import 'linked_markdown_body.dart';

/// Tappable link from a reflection thread back to its source content.
class ReflectionSourceLink extends ConsumerWidget {
  const ReflectionSourceLink({
    super.key,
    required this.thread,
  });

  final ReflectionThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ReflectionSource.hasNavigableSource(thread.source)) {
      return const SizedBox.shrink();
    }

    final label = ReflectionSource.label(thread.source);
    final subtitle = thread.linkedSourceTitle?.trim().isNotEmpty == true
        ? thread.linkedSourceTitle!.trim()
        : thread.linkedQuestionText?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.parchment,
      child: InkWell(
        onTap: () => _openSource(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                _iconFor(thread.source),
                color: AppColors.primaryMaroon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'View source · $label',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String? source) {
    switch (source) {
      case ReflectionSource.giftActivity:
        return Icons.card_giftcard_outlined;
      case ReflectionSource.sharedJourney:
        return Icons.groups_outlined;
      case ReflectionSource.wisdomSession:
      default:
        return Icons.menu_book_outlined;
    }
  }

  Future<void> _openSource(BuildContext context, WidgetRef ref) async {
    switch (thread.source) {
      case ReflectionSource.giftActivity:
        final giftId = thread.linkedGiftId?.trim();
        if (giftId == null || giftId.isEmpty) {
          _missingSource(context);
          return;
        }
        context.push(GiftActivityLink.path(giftId));
        return;
      case ReflectionSource.sharedJourney:
        await _openSharedJourney(context, ref);
        return;
      case ReflectionSource.wisdomSession:
        _openWisdomSession(context);
        return;
      default:
        _missingSource(context);
    }
  }

  void _openWisdomSession(BuildContext context) {
    final question = thread.linkedQuestionText?.trim();
    final response = thread.linkedResponseText?.trim();

    if ((question == null || question.isEmpty) &&
        (response == null || response.isEmpty)) {
      _missingSource(context);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Seeking God's Wisdom"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (question != null && question.isNotEmpty) ...[
                const Text(
                  'Your question',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(question),
                const SizedBox(height: 16),
              ],
              if (response != null && response.isNotEmpty) ...[
                const Text(
                  'WWJD response',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                LinkedMarkdownBody(data: response),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSharedJourney(BuildContext context, WidgetRef ref) async {
    final journeyId = thread.linkedJourneyId?.trim();
    if (journeyId == null || journeyId.isEmpty) {
      _missingSource(context);
      return;
    }

    WalkTogetherJourney? journey;
    try {
      journey = await ref.read(walkTogetherServiceProvider).getJourney(journeyId);
    } catch (_) {
      journey = null;
    }

    if (!context.mounted) return;
    if (journey == null) {
      _missingSource(context);
      return;
    }

    _showJourneySheet(context, journey);
  }

  void _showJourneySheet(BuildContext context, WalkTogetherJourney journey) {
    final isGift = journey.isGiftShare;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  journey.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isGift) ...[
                  const SizedBox(height: 8),
                  Text(
                    journey.attributionLine,
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  isGift ? 'Kingdom Challenge' : 'Question',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SelectableText(journey.question),
                const SizedBox(height: 20),
                Text(
                  isGift ? 'Challenge' : 'WWJD Response',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                LinkedMarkdownBody(data: journey.response),
              ],
            ),
          );
        },
      ),
    );
  }

  void _missingSource(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The original source is no longer available.'),
      ),
    );
  }
}
