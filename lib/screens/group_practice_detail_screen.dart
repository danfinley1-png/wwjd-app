import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/catholic_prayers/prayer_gift_link.dart';
import '../core/group_practice_tracking.dart';
import '../core/mobile_touch.dart';
import '../core/prayer_link.dart';
import '../core/providers/app_providers.dart';
import '../models/group_practice_instance.dart';
import '../widgets/gift_prayer_link_tile.dart';

/// Detail view for a synced group practice (member-facing).
class GroupPracticeDetailScreen extends ConsumerWidget {
  const GroupPracticeDetailScreen({
    super.key,
    required this.practice,
  });

  final GroupPracticeInstance practice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = GroupPracticeTracking.timesSummary(practice);
    final dueNow = GroupPracticeTracking.isDueNow(practice);
    final nextSlot = GroupPracticeTracking.nextDueSlotLabel(practice);
    final linkedPrayerId = PrayerGiftLink.resolveGroupPracticePrayerId(practice);

    return Scaffold(
      appBar: AppBar(
        title: Text(practice.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (practice.groupName != null || practice.organizationName != null)
            Card(
              color: AppColors.parchmentDark,
              child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(practice.groupName ?? 'Group practice'),
                subtitle: Text(
                  [
                    if (practice.organizationName != null)
                      practice.organizationName!,
                    'Shared by your organization',
                  ].join(' · '),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (practice.description.isNotEmpty) ...[
            Text(
              practice.description,
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 16),
          ],
          if (linkedPrayerId != null) ...[
            GiftPrayerLinkTile(prayerId: linkedPrayerId),
            const SizedBox(height: 16),
          ],
          Text(
            summary,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (dueNow) ...[
            const SizedBox(height: 8),
            Text(
              'Next due: $nextSlot',
              style: const TextStyle(color: AppColors.primaryMaroon),
            ),
          ],
          const SizedBox(height: 20),
          if (practice.practiceText != null &&
              practice.practiceText!.trim().isNotEmpty) ...[
            const Text(
              'Practice',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SelectableText(
              practice.practiceText!,
              style: const TextStyle(height: 1.5, fontSize: 15),
            ),
          ],
          if (practice.practiceLink != null &&
              practice.practiceLink!.trim().isNotEmpty &&
              linkedPrayerId == null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openExternalLink(context, practice.practiceLink!),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open practice link'),
              style: mobileTextButtonStyle(context),
            ),
          ],
          const SizedBox(height: 24),
          if (dueNow)
            FilledButton.icon(
              onPressed: () => _complete(context, ref),
              icon: const Icon(Icons.check),
              label: Text('Mark $nextSlot complete'),
            ),
          if (practice.currentStreak > 0) ...[
            const SizedBox(height: 16),
            Text(
              '${practice.currentStreak}-day streak · '
              '${practice.totalCompletions} completion${practice.totalCompletions == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openExternalLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (uri.path.startsWith(PrayerLink.pathPrefix)) {
      final prayerId = PrayerGiftLink.prayerIdFromUrl(url);
      if (prayerId != null && context.mounted) {
        context.push(PrayerLink.path(prayerId));
        return;
      }
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    try {
      final updated = await ref
          .read(groupPracticeServiceProvider)
          .completeNextSlot(practice);
      if (!context.mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All slots complete for today.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.currentStreak > 1
                ? 'Completed · ${updated.currentStreak}-day streak!'
                : 'Practice marked complete',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }
}
