import 'package:cloud_firestore/cloud_firestore.dart';

/// A community journey shared to Walk Together (visible to all signed-in users).
class WalkTogetherJourney {
  final String id;
  final String title;
  final String question;
  final String response;
  final int upvotes;
  final DateTime createdAt;
  final String? createdByUid;
  final String? shareType;
  final String? linkedActivityId;
  final String? giftDescription;
  final String? personalNote;
  final bool shareAnonymously;
  final String? sharedByDisplayName;
  final String? favoriteSaint;

  const WalkTogetherJourney({
    required this.id,
    required this.title,
    required this.question,
    required this.response,
    this.upvotes = 0,
    required this.createdAt,
    this.createdByUid,
    this.shareType,
    this.linkedActivityId,
    this.giftDescription,
    this.personalNote,
    this.shareAnonymously = true,
    this.sharedByDisplayName,
    this.favoriteSaint,
  });

  bool get isGiftShare => shareType == 'gift';

  bool get isReflectionShare => !isGiftShare;

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

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'question': question,
      'response': response,
      'upvotes': upvotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdByUid': createdByUid,
      if (shareType != null) 'shareType': shareType,
      if (linkedActivityId != null) 'linkedActivityId': linkedActivityId,
      if (giftDescription != null) 'giftDescription': giftDescription,
      if (personalNote != null) 'personalNote': personalNote,
      'shareAnonymously': shareAnonymously,
      if (sharedByDisplayName != null) 'sharedByDisplayName': sharedByDisplayName,
      if (favoriteSaint != null) 'favoriteSaint': favoriteSaint,
    };
  }

  factory WalkTogetherJourney.fromMap(String id, Map<String, dynamic> map) {
    return WalkTogetherJourney(
      id: id,
      title: map['title']?.toString() ?? 'Shared Journey',
      question: map['question']?.toString() ?? '',
      response: map['response']?.toString() ?? '',
      upvotes: (map['upvotes'] as num?)?.toInt() ?? 0,
      createdAt: _parseTimestamp(map['createdAt']),
      createdByUid: map['createdByUid']?.toString(),
      shareType: map['shareType']?.toString(),
      linkedActivityId: map['linkedActivityId']?.toString(),
      giftDescription: map['giftDescription']?.toString(),
      personalNote: map['personalNote']?.toString(),
      shareAnonymously: map['shareAnonymously'] as bool? ?? true,
      sharedByDisplayName: map['sharedByDisplayName']?.toString(),
      favoriteSaint: map['favoriteSaint']?.toString(),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}
