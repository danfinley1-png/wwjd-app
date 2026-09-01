import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';
import '../core/catholic_prayers/prayer_gift_link.dart';
import '../core/providers/reflection_providers.dart';
import '../models/gift_activity.dart';
import '../widgets/gift_prayer_link_tile.dart';
import '../widgets/group_brand_mark.dart';
import 'reflection_detail_screen.dart';

/// Read-only completion record for a Gift. Private reflection body stays in
/// My Reflections.
class GiftDoneDetailScreen extends ConsumerWidget {
  const GiftDoneDetailScreen({
    super.key,
    required this.gift,
    required this.completedOn,
  });

  final GiftActivity gift;
  final DateTime completedOn;

  static final _dateFormat = DateFormat('EEEE, MMMM d, yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerId = PrayerGiftLink.resolvePrayerId(gift);
    final description = gift.description.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Gift'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (gift.isGroupGift)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  GroupBrandMark(
                    groupName: gift.brandLabel,
                    logoUrl: gift.groupLogoUrl,
                    orgId: gift.organizationId,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      gift.brandLabel,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            gift.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryMaroon,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completed ${_dateFormat.format(completedOn)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (gift.frequency.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              gift.frequency,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(fontSize: 16, height: 1.45),
            ),
          ],
          if (prayerId != null) ...[
            const SizedBox(height: 20),
            GiftPrayerLinkTile(prayerId: prayerId),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _openReflection(context, ref),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Open My Reflections'),
          ),
        ],
      ),
    );
  }

  Future<void> _openReflection(BuildContext context, WidgetRef ref) async {
    try {
      final thread = await ref
          .read(reflectionServiceProvider)
          .findThreadForGift(gift.id);
      if (!context.mounted) return;
      if (thread == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No linked reflection yet for this Gift.'),
          ),
        );
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ReflectionDetailScreen(threadId: thread.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open reflection: $e')),
      );
    }
  }
}
