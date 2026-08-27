import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/walk_together_journey.dart';
import 'gift_share_payload.dart';

/// Extends [WalkTogetherService.addJourney] with gift-specific metadata.
class WalkTogetherGiftShare {
  WalkTogetherGiftShare._();

  static Map<String, dynamic> journeyMapFromPayload(
    GiftSharePayload payload, {
    required String createdByUid,
    required DateTime createdAt,
  }) {
    final fields = payload.toWalkTogetherFields();
    return {
      ...fields,
      'upvotes': 0,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdByUid': createdByUid,
    };
  }

  static WalkTogetherJourney journeyFromPayload(
    String id,
    GiftSharePayload payload, {
    required String createdByUid,
    required DateTime createdAt,
  }) {
    return WalkTogetherJourney(
      id: id,
      title: payload.title.trim(),
      question: 'Kingdom Challenge: ${payload.title.trim()}',
      response: payload.activityBody,
      createdAt: createdAt,
      createdByUid: createdByUid,
      shareType: 'gift',
      linkedActivityId: payload.linkedActivityId,
      giftDescription: payload.description.trim(),
      personalNote: payload.personalNote.trim().isEmpty
          ? null
          : payload.personalNote.trim(),
      shareAnonymously: payload.shareAnonymously,
      sharedByDisplayName:
          payload.shareAnonymously ? null : payload.displayName?.trim(),
      favoriteSaint:
          payload.shareAnonymously ? null : payload.favoriteSaint?.trim(),
    );
  }
}
