import 'package:cloud_firestore/cloud_firestore.dart';

/// Product-issue feedback for WWJD-DI — never spiritual journaling.
///
/// Stored at `productFeedback/{id}`. Must not include Seeking God's Wisdom
/// question or reply text.
enum ProductFeedbackType {
  bug,
  suggestion,
  other,
}

extension ProductFeedbackTypeLabels on ProductFeedbackType {
  String get label {
    switch (this) {
      case ProductFeedbackType.bug:
        return 'Bug';
      case ProductFeedbackType.suggestion:
        return 'Suggestion';
      case ProductFeedbackType.other:
        return 'Other';
    }
  }

  String get firestoreValue {
    switch (this) {
      case ProductFeedbackType.bug:
        return 'bug';
      case ProductFeedbackType.suggestion:
        return 'suggestion';
      case ProductFeedbackType.other:
        return 'other';
    }
  }
}

ProductFeedbackType productFeedbackTypeFromFirestore(String? value) {
  switch (value) {
    case 'bug':
      return ProductFeedbackType.bug;
    case 'suggestion':
      return ProductFeedbackType.suggestion;
    default:
      return ProductFeedbackType.other;
  }
}

class ProductFeedback {
  static const String collectionName = 'productFeedback';
  static const int maxTextLength = 1000;

  /// Keys that must never appear on a product-feedback document.
  static const Set<String> forbiddenSpiritualKeys = {
    'question',
    'questionText',
    'message',
    'reply',
    'replyText',
    'chatText',
    'reflection',
    'spiritualContent',
  };

  final String id;
  final String uid;
  final String text;
  final ProductFeedbackType type;
  final String? email;
  final String? displayName;
  final DateTime createdAt;

  const ProductFeedback({
    required this.id,
    required this.uid,
    required this.text,
    required this.type,
    this.email,
    this.displayName,
    required this.createdAt,
  });

  String get contactLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    return 'Signed-in user';
  }

  factory ProductFeedback.fromMap(String id, Map<String, dynamic> map) {
    for (final key in forbiddenSpiritualKeys) {
      if (map.containsKey(key)) {
        throw FormatException(
          'Product feedback must not include spiritual content ($key).',
        );
      }
    }
    return ProductFeedback(
      id: id,
      uid: map['uid']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      type: productFeedbackTypeFromFirestore(map['type']?.toString()),
      email: map['email']?.toString(),
      displayName: map['displayName']?.toString(),
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

/// Compact Helpful? vote on a Seeking God's Wisdom reply.
///
/// Stored at `replyHelpfulVotes/{id}`. Only the flag and optional theme —
/// never question text, uid, email, or display name.
class ReplyHelpfulVote {
  static const String collectionName = 'replyHelpfulVotes';

  final String id;
  final bool helpful;
  final String? theme;
  final DateTime createdAt;

  const ReplyHelpfulVote({
    required this.id,
    required this.helpful,
    this.theme,
    required this.createdAt,
  });

  factory ReplyHelpfulVote.fromMap(String id, Map<String, dynamic> map) {
    for (final key in ProductFeedback.forbiddenSpiritualKeys) {
      if (map.containsKey(key)) {
        throw FormatException(
          'Helpful votes must not include spiritual content ($key).',
        );
      }
    }
    if (map.containsKey('uid') ||
        map.containsKey('email') ||
        map.containsKey('displayName') ||
        map.containsKey('text')) {
      throw FormatException(
        'Helpful votes store only the flag and optional theme.',
      );
    }
    return ReplyHelpfulVote(
      id: id,
      helpful: map['helpful'] == true,
      theme: map['theme']?.toString(),
      createdAt: ProductFeedback._parseTimestamp(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
