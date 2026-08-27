import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../core/providers/app_providers.dart';
import '../models/gift_activity.dart';
import 'activity_detail_screen.dart';

/// Opens a gift activity from a reminder or calendar deep link (`/gift/:id`).
class GiftActivityScreen extends ConsumerWidget {
  const GiftActivityScreen({super.key, required this.giftId});

  final String giftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giftsAsync = ref.watch(userGiftsStreamProvider);

    return giftsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => _messageScaffold(
        context,
        title: 'Could not load activity',
        body: '$err',
      ),
      data: (gifts) {
        GiftActivity? gift;
        for (final item in gifts) {
          if (item.id == giftId) {
            gift = item;
            break;
          }
        }

        if (gift == null) {
          return _messageScaffold(
            context,
            title: 'Activity not found',
            body:
                'This Kingdom Challenge may have been removed, or you may need to sign in to the account that owns it.',
          );
        }

        final resolved = gift;
        return ActivityDetailScreen(
          activity: resolved,
          onUpdate: (updated) {
            ref.read(giftServiceProvider).saveGift(updated);
          },
        );
      },
    );
  }

  Widget _messageScaffold(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kingdom Challenge'),
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
                Icons.card_giftcard_outlined,
                size: 56,
                color: AppColors.primaryMaroon.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(body, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
