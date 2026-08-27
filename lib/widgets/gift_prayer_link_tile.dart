import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../core/catholic_prayers/catholic_prayer_catalog.dart';
import '../core/prayer_link.dart';

/// Tappable link from a Gift or group practice into the Prayers library.
class GiftPrayerLinkTile extends StatelessWidget {
  const GiftPrayerLinkTile({
    super.key,
    required this.prayerId,
    this.compact = false,
  });

  final String prayerId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final prayer = CatholicPrayerCatalog.byId(prayerId);
    if (prayer == null) return const SizedBox.shrink();

    if (compact) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.push(PrayerLink.path(prayerId)),
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: Text('Open ${prayer.displayName}'),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.parchmentDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                color: AppColors.primaryMaroon.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Prayer in WWJD-DI',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Read, listen to, or share the full text of ${prayer.displayName}.',
            style: TextStyle(color: Colors.grey.shade800, height: 1.45),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => context.push(PrayerLink.path(prayerId)),
            icon: const Icon(Icons.open_in_new),
            label: Text('Open ${prayer.displayName}'),
          ),
        ],
      ),
    );
  }
}
