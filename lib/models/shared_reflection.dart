import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/gift_share_payload.dart';

/// A shareable WWJD reflection stored at `shares/{id}` for deep links.
class SharedReflection {
  final String id;
  final String question;
  final String response;
  final String title;
  final String? createdByUid;
  final DateTime? createdAt;
  final String? shareType;
  final bool shareAnonymously;
  final String? sharedByDisplayName;
  final String? favoriteSaint;
  final String? personalNote;
  final String? linkedActivityId;
  final String? linkedPrayerId;
  final String? giftDescription;

  const SharedReflection({
    required this.id,
    required this.question,
    required this.response,
    required this.title,
    this.createdByUid,
    this.createdAt,
    this.shareType,
    this.shareAnonymously = true,
    this.sharedByDisplayName,
    this.favoriteSaint,
    this.personalNote,
    this.linkedActivityId,
    this.linkedPrayerId,
    this.giftDescription,
  });

  bool get isGiftShare => shareType == 'gift';

  /// Raw challenge text for importing — excludes sharer's personal note.
  String get importableDescription =>
      giftDescription?.trim().isNotEmpty == true
          ? giftDescription!.trim()
          : response.trim();

  String get attributionLine {
    if (sharedByDisplayName != null &&
        sharedByDisplayName!.trim().isNotEmpty &&
        !shareAnonymously) {
      final saint = favoriteSaint?.trim();
      if (saint != null && saint.isNotEmpty) {
        return 'Shared by ${sharedByDisplayName!.trim()} · Friend of $saint';
      }
      return 'Shared by ${sharedByDisplayName!.trim()}';
    }
    return 'Shared anonymously';
  }

  factory SharedReflection.fromMap(String id, Map<String, dynamic> map) {
    return SharedReflection(
      id: id,
      question: map['question']?.toString() ?? '',
      response: map['response']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Shared Reflection',
      createdByUid: map['createdByUid']?.toString(),
      createdAt: _parseTimestamp(map['createdAt']),
      shareType: map['shareType']?.toString(),
      shareAnonymously: map['shareAnonymously'] as bool? ?? true,
      sharedByDisplayName: map['sharedByDisplayName']?.toString(),
      favoriteSaint: map['favoriteSaint']?.toString(),
      personalNote: map['personalNote']?.toString(),
      linkedActivityId: map['linkedActivityId']?.toString(),
      linkedPrayerId: map['linkedPrayerId']?.toString(),
      giftDescription: map['giftDescription']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'response': response,
      'title': title,
      'createdByUid': createdByUid,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      if (shareType != null) 'shareType': shareType,
      'shareAnonymously': shareAnonymously,
      if (sharedByDisplayName != null) 'sharedByDisplayName': sharedByDisplayName,
      if (favoriteSaint != null) 'favoriteSaint': favoriteSaint,
      if (personalNote != null) 'personalNote': personalNote,
      if (linkedActivityId != null) 'linkedActivityId': linkedActivityId,
      if (linkedPrayerId != null) 'linkedPrayerId': linkedPrayerId,
      if (giftDescription != null) 'giftDescription': giftDescription,
      'brand': GiftSharePayload.brandName,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
