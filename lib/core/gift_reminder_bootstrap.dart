import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'gift_activity_link.dart';
import 'providers/app_providers.dart';
import 'services/gift_reminder_service.dart';

/// Reschedules native gift reminders once when gifts load after app start.
class GiftReminderBootstrap extends ConsumerStatefulWidget {
  const GiftReminderBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GiftReminderBootstrap> createState() =>
      _GiftReminderBootstrapState();
}

class _GiftReminderBootstrapState extends ConsumerState<GiftReminderBootstrap> {
  bool _synced = false;
  bool _tapHandlerRegistered = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      GiftReminderService.instance.init();
    }
  }

  void _openGiftActivity(String giftId) {
    if (!mounted) return;
    context.go(GiftActivityLink.path(giftId));
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      if (!_tapHandlerRegistered) {
        _tapHandlerRegistered = true;
        GiftReminderService.instance.setTapHandler(_openGiftActivity);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          GiftReminderService.instance.consumePendingLaunchTap();
        });
      }

      ref.listen(userGiftsStreamProvider, (previous, next) {
        if (_synced || !next.hasValue) return;
        _synced = true;
        GiftReminderService.instance.syncAll(next.requireValue);
      });
    }

    return widget.child;
  }
}
