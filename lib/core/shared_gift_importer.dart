import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/gift_activity.dart';
import 'catholic_prayers/prayer_gift_link.dart';
import 'gift_reminder_utils.dart';
import 'services/gift_service.dart';

/// Result of importing a shared Kingdom Challenge into My Gifts.
class SharedGiftImportResult {
  final bool added;
  final bool duplicate;

  const SharedGiftImportResult({required this.added, required this.duplicate});
}

/// Adds a community- or link-shared Gift to the current user's plan.
Future<SharedGiftImportResult> importSharedGiftToPlan({
  required WidgetRef ref,
  required GiftService giftService,
  required String title,
  required String description,
  String? sharedByLine,
  String? shareSourceId,
  String frequency = 'Daily',
  String? linkedPrayerId,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    throw Exception('Sign in to add this Gift to your plan.');
  }

  final trimmedTitle = title.trim();
  final trimmedDescription = description.trim();
  if (trimmedTitle.isEmpty || trimmedDescription.isEmpty) {
    throw Exception('This shared Gift is missing a title or description.');
  }

  final activity = GiftActivity(
    id: const Uuid().v4(),
    title: trimmedTitle,
    description: trimmedDescription,
    linkedQuestionId: shareSourceId,
    linkedQuestionText: sharedByLine ?? 'Shared Kingdom Challenge',
    linkedResponseText: null,
    linkedPrayerId: linkedPrayerId ??
        PrayerGiftLink.detectPrayerId(
          title: trimmedTitle,
          description: trimmedDescription,
        ),
    frequency: frequency,
    hasReminder: true,
    specificTime: GiftReminderUtils.formatStoredTime(
      GiftReminderUtils.defaultTime,
    ),
    userId: uid,
    createdAt: DateTime.now(),
  );

  final result = await giftService.saveGiftsSkippingDuplicates([activity]);
  return SharedGiftImportResult(
    added: result.added > 0,
    duplicate: result.skipped > 0,
  );
}

/// Builds a pastoral attribution line for linked question text.
String sharedGiftAttributionLine({
  required bool shareAnonymously,
  String? displayName,
  String? favoriteSaint,
}) {
  if (shareAnonymously) {
    return 'Shared anonymously via WWJD-DI';
  }
  final name = displayName?.trim();
  if (name == null || name.isEmpty) return 'Shared via WWJD-DI';
  final saint = favoriteSaint?.trim();
  if (saint != null && saint.isNotEmpty) {
    return 'Shared by $name · Friend of $saint';
  }
  return 'Shared by $name';
}
