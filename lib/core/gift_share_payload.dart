/// Branded share payload for Kingdom Challenge / Gift activities.
import 'catholic_prayers/catholic_prayer_catalog.dart';
import 'prayer_link.dart';

class GiftSharePayload {
  const GiftSharePayload({
    required this.title,
    required this.description,
    this.personalNote = '',
    this.shareAnonymously = true,
    this.displayName,
    this.favoriteSaint,
    this.linkedActivityId,
    this.linkedPrayerId,
  });

  final String title;
  final String description;
  final String personalNote;
  final bool shareAnonymously;
  final String? displayName;
  final String? favoriteSaint;
  final String? linkedActivityId;
  final String? linkedPrayerId;

  static const String brandName = 'WWJD-DI';
  static const String brandTagline =
      'What Would Jesus Do — Discernment & Inspiration';

  String get attributionLine {
    if (shareAnonymously) {
      return 'Shared anonymously via $brandName';
    }
    final name = displayName?.trim();
    if (name == null || name.isEmpty) {
      return 'Shared via $brandName';
    }
    final saint = favoriteSaint?.trim();
    if (saint != null && saint.isNotEmpty) {
      return 'Shared by $name · Friend of $saint · via $brandName';
    }
    return 'Shared by $name · via $brandName';
  }

  String get activityBody {
    final parts = <String>[description.trim()];
    final note = personalNote.trim();
    if (note.isNotEmpty) {
      parts.add('A note from the sharer:\n"$note"');
    }
    final prayerLine = _prayerShareLine();
    if (prayerLine != null) {
      parts.add(prayerLine);
    }
    return parts.join('\n\n');
  }

  String? _prayerShareLine() {
    final id = linkedPrayerId?.trim();
    if (id == null || id.isEmpty) return null;
    final prayer = CatholicPrayerCatalog.byId(id);
    if (prayer == null) return null;
    return 'Prayer text (${prayer.displayName}): ${PrayerLink.url(id)}';
  }

  /// Text for native share sheet / clipboard (includes URL when provided).
  String formatShareText({String? url}) {
    final buffer = StringBuffer()
      ..writeln('$brandName — Kingdom Challenge')
      ..writeln(brandTagline)
      ..writeln()
      ..writeln(title.trim())
      ..writeln()
      ..writeln(activityBody)
      ..writeln()
      ..writeln(attributionLine);

    if (url != null && url.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(url.trim());
    }

    return buffer.toString().trim();
  }

  /// Firestore document for `shares/{id}` — ready for Walk Together reuse.
  Map<String, dynamic> toShareDocument({
    required String? createdByUid,
  }) {
    return {
      'title': title.trim(),
      'question': 'Kingdom Challenge: ${title.trim()}',
      'response': activityBody,
      'giftDescription': description.trim(),
      'shareType': 'gift',
      'linkedActivityId': linkedActivityId,
      if (linkedPrayerId != null && linkedPrayerId!.trim().isNotEmpty)
        'linkedPrayerId': linkedPrayerId!.trim(),
      'shareAnonymously': shareAnonymously,
      'sharedByDisplayName':
          shareAnonymously ? null : displayName?.trim(),
      'favoriteSaint':
          shareAnonymously ? null : favoriteSaint?.trim(),
      'personalNote': personalNote.trim().isEmpty ? null : personalNote.trim(),
      'createdByUid': createdByUid,
      'brand': brandName,
      'createdAt': null, // set by ShareService
    };
  }

  /// Fields for Walk Together community feed.
  Map<String, dynamic> toWalkTogetherFields() {
    return {
      'title': title.trim(),
      'question': 'Kingdom Challenge: ${title.trim()}',
      'response': activityBody,
      'giftDescription': description.trim(),
      'personalNote': personalNote.trim().isEmpty ? null : personalNote.trim(),
      'shareType': 'gift',
      'linkedActivityId': linkedActivityId,
      if (linkedPrayerId != null && linkedPrayerId!.trim().isNotEmpty)
        'linkedPrayerId': linkedPrayerId!.trim(),
      'shareAnonymously': shareAnonymously,
      'sharedByDisplayName':
          shareAnonymously ? null : displayName?.trim(),
      'favoriteSaint':
          shareAnonymously ? null : favoriteSaint?.trim(),
      'brand': brandName,
    };
  }
}
