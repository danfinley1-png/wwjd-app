import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/pastoral_theme.dart';
import '../../models/product_feedback.dart';

/// Writes product-issue feedback. Never copies chat or reflection text.
///
/// Collections:
/// - [ProductFeedback.collectionName] — signed-in form (uid for follow-up)
/// - [ReplyHelpfulVote.collectionName] — helpful flag + optional theme only
class ProductFeedbackService {
  ProductFeedbackService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String confirmationMessage =
      'Thank you. This goes to the WWJD-DI team, not to your group.';

  static const Set<String> allowedProfileKeys = {
    'uid',
    'email',
    'displayName',
    'text',
    'type',
    'source',
    'createdAt',
  };

  static const Set<String> allowedHelpfulKeys = {
    'helpful',
    'theme',
    'source',
    'createdAt',
  };

  static const Set<String> allowedThemes = {
    'prayer',
    'sacraments',
    'scripture',
    'relationships_chastity',
    'suffering_grief',
    'vocation',
    'moral_decision',
    'other',
  };

  /// Builds the profile-form document. Does not accept question or reply text.
  static Map<String, dynamic> buildProfileDocument({
    required String uid,
    required String text,
    ProductFeedbackType type = ProductFeedbackType.other,
    String? email,
    String? displayName,
    Object? createdAt,
  }) {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      throw ArgumentError('Sign in to send feedback.');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Enter a short note about the app.');
    }
    if (trimmed.length > ProductFeedback.maxTextLength) {
      throw ArgumentError(
        'Keep feedback to ${ProductFeedback.maxTextLength} characters.',
      );
    }

    final payload = <String, dynamic>{
      'uid': trimmedUid,
      'text': trimmed,
      'type': type.firestoreValue,
      'source': 'profile',
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };

    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) {
      payload['email'] = mail;
    }

    final name = displayName?.trim();
    if (name != null &&
        name.isNotEmpty &&
        !name.contains('@') &&
        name.toLowerCase() != 'guest') {
      payload['displayName'] = name;
    }

    _assertNoSpiritualKeys(payload);
    return payload;
  }

  /// Builds a Helpful? vote. [theme] is a tag only — never question text.
  static Map<String, dynamic> buildHelpfulDocument({
    required bool helpful,
    String? theme,
    Object? createdAt,
  }) {
    final payload = <String, dynamic>{
      'helpful': helpful,
      'source': 'seeking_gods_wisdom',
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
    final tag = theme?.trim();
    if (tag != null && tag.isNotEmpty && allowedThemes.contains(tag)) {
      payload['theme'] = tag;
    }
    _assertNoSpiritualKeys(payload);
    if (payload.containsKey('uid') ||
        payload.containsKey('email') ||
        payload.containsKey('displayName') ||
        payload.containsKey('text')) {
      throw StateError('Helpful votes must not include identity or text.');
    }
    return payload;
  }

  static String? themeTagOrNull(PastoralThemeCategory? theme) {
    if (theme == null) return null;
    return theme.firestoreValue;
  }

  static void _assertNoSpiritualKeys(Map<String, dynamic> payload) {
    for (final key in ProductFeedback.forbiddenSpiritualKeys) {
      if (payload.containsKey(key)) {
        throw StateError('Product feedback must not include $key.');
      }
    }
  }

  Future<void> submitProfileFeedback({
    required String text,
    ProductFeedbackType? type,
    String? displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to send feedback.');
    }
    final payload = buildProfileDocument(
      uid: user.uid,
      text: text,
      type: type ?? ProductFeedbackType.other,
      email: user.email,
      displayName: displayName,
    );
    await _firestore.collection(ProductFeedback.collectionName).add(payload);
  }

  Future<void> submitHelpfulVote({
    required bool helpful,
    String? theme,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to send feedback.');
    }
    final payload = buildHelpfulDocument(helpful: helpful, theme: theme);
    await _firestore.collection(ReplyHelpfulVote.collectionName).add(payload);
  }

  Stream<List<ProductFeedback>> watchFeedback({int limit = 200}) {
    return _firestore
        .collection(ProductFeedback.collectionName)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ProductFeedback.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<ReplyHelpfulVote>> watchHelpfulVotes({int limit = 200}) {
    return _firestore
        .collection(ReplyHelpfulVote.collectionName)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ReplyHelpfulVote.fromMap(doc.id, doc.data()))
            .toList());
  }
}
