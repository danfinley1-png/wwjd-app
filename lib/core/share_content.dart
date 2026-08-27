import 'gift_share_payload.dart';

enum ShareContentKind { reflection, gift }

/// Describes shareable content from any screen in WWJD-DI.
class ShareContent {
  const ShareContent({
    required this.kind,
    required this.title,
    required this.question,
    required this.response,
    this.previewSubtitle,
    this.linkedActivityId,
    this.linkedPrayerId,
    this.allowWalkTogether = true,
  });

  final ShareContentKind kind;
  final String title;
  final String question;
  final String response;
  final String? previewSubtitle;
  final String? linkedActivityId;
  final String? linkedPrayerId;
  final bool allowWalkTogether;

  bool get isGift => kind == ShareContentKind.gift;

  String get confirmTitle =>
      isGift ? 'Share Gift' : 'Share Reflection';

  String get previewTitle => title.trim();

  String get previewBody {
    if (previewSubtitle != null && previewSubtitle!.trim().isNotEmpty) {
      return previewSubtitle!.trim();
    }
    if (isGift) return response.trim();
    final q = question.trim();
    if (q.length <= 160) return q;
    return '${q.substring(0, 157)}...';
  }

  factory ShareContent.gift({
    required String title,
    required String description,
    String? linkedActivityId,
    String? linkedPrayerId,
  }) {
    return ShareContent(
      kind: ShareContentKind.gift,
      title: title.trim(),
      question: 'Kingdom Challenge: ${title.trim()}',
      response: description.trim(),
      previewSubtitle: description.trim(),
      linkedActivityId: linkedActivityId,
      linkedPrayerId: linkedPrayerId,
    );
  }

  factory ShareContent.reflection({
    required String question,
    required String response,
    String? title,
  }) {
    return ShareContent(
      kind: ShareContentKind.reflection,
      title: title?.trim().isNotEmpty == true ? title!.trim() : 'Shared Reflection',
      question: question.trim(),
      response: response.trim(),
      previewSubtitle: question.trim(),
    );
  }

  static String bodyWithOptionalNote({
    required String body,
    required String personalNote,
  }) {
    final trimmed = body.trim();
    final note = personalNote.trim();
    if (note.isEmpty) return trimmed;
    return '$trimmed\n\nA note from the sharer:\n"$note"';
  }

  static String formatShareText({
    required ShareContent content,
    required bool shareAnonymously,
    String? displayName,
    String? favoriteSaint,
    String? personalNote,
    String? url,
  }) {
    final body = bodyWithOptionalNote(
      body: content.response,
      personalNote: personalNote ?? '',
    );

    final buffer = StringBuffer()
      ..writeln('${GiftSharePayload.brandName} — ${content.confirmTitle.replaceFirst('Share ', '')}')
      ..writeln(GiftSharePayload.brandTagline)
      ..writeln()
      ..writeln(content.previewTitle);

    if (!content.isGift) {
      buffer
        ..writeln()
        ..writeln(content.question.trim());
    }

    buffer
      ..writeln()
      ..writeln(body)
      ..writeln()
      ..writeln(_attributionLine(
        shareAnonymously: shareAnonymously,
        displayName: displayName,
        favoriteSaint: favoriteSaint,
      ));

    if (url != null && url.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(url.trim());
    }

    return buffer.toString().trim();
  }

  static String _attributionLine({
    required bool shareAnonymously,
    String? displayName,
    String? favoriteSaint,
  }) {
    if (shareAnonymously) {
      return 'Shared anonymously via ${GiftSharePayload.brandName}';
    }
    final name = displayName?.trim();
    if (name == null || name.isEmpty) {
      return 'Shared via ${GiftSharePayload.brandName}';
    }
    final saint = favoriteSaint?.trim();
    if (saint != null && saint.isNotEmpty) {
      return 'Shared by $name · Friend of $saint · via ${GiftSharePayload.brandName}';
    }
    return 'Shared by $name · via ${GiftSharePayload.brandName}';
  }
}
