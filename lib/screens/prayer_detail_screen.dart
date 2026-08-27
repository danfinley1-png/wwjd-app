import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_colors.dart';
import '../core/catholic_prayers/catholic_prayer_catalog.dart';
import '../core/prayer_link.dart';
import '../widgets/prayer_read_aloud_button.dart';

/// Full-text view for a single Catholic prayer with listen and share actions.
class PrayerDetailScreen extends StatelessWidget {
  const PrayerDetailScreen({
    super.key,
    required this.prayer,
  });

  final CatholicPrayer prayer;

  void _copyLink(BuildContext context) {
    final url = PrayerLink.url(prayer.id);
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prayer link copied to clipboard')),
    );
  }

  Future<void> _shareLink(BuildContext context) async {
    await SharePlus.instance.share(
      ShareParams(
        subject: prayer.displayName,
        text: PrayerLink.shareText(
          displayName: prayer.displayName,
          prayerId: prayer.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          prayer.displayName,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          PrayerReadAloudButton(text: prayer.body, compact: true),
          IconButton(
            tooltip: 'Copy link',
            icon: const Icon(Icons.link),
            onPressed: () => _copyLink(context),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareLink(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.parchmentDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prayer.displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        prayer.body,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.65,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (prayer.attribution != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          prayer.attribution!,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    PrayerReadAloudButton(text: prayer.body),
                    OutlinedButton.icon(
                      onPressed: () => _copyLink(context),
                      icon: const Icon(Icons.link),
                      label: const Text('Copy Link'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _shareLink(context),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a prayer from a deep link (`/prayer/:id`).
class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key, required this.prayerId});

  final String prayerId;

  @override
  Widget build(BuildContext context) {
    final prayer = CatholicPrayerCatalog.byId(prayerId);

    if (prayer == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Prayer'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 56,
                  color: AppColors.primaryMaroon.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Prayer not found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'This link may be outdated or the prayer name is not in our library.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(PrayerLink.listPath),
                  child: const Text('Browse Prayers'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PrayerDetailScreen(prayer: prayer);
  }
}
