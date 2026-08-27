import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/walk_together_journey.dart';
import '../content_guidance/content_guidance_models.dart';
import '../content_guidance/shared_content_gate.dart';
import '../gift_share_payload.dart';
import '../walk_together_gift_share.dart';

class WalkTogetherService {
  WalkTogetherService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _journeys =>
      _firestore.collection('walkTogether');

  /// Real-time community feed — same data for every signed-in user.
  Stream<List<WalkTogetherJourney>> getJourneysStream() {
    return _journeys
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => WalkTogetherJourney.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Returns `true` when a new journey was added, `false` if it already exists.
  Future<bool> addJourney({
    required String title,
    required String question,
    required String response,
    String? shareType,
    String? linkedActivityId,
    bool shareAnonymously = true,
    String? sharedByDisplayName,
    String? favoriteSaint,
    String? personalNote,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to share to Walk Together.');
    }

    final prepared = sharedContentGate.processSilently(
      SharedContentInput(
        title: title,
        question: question,
        response: response,
        personalNote: personalNote,
      ),
      channel: SharedContentChannel.walkTogether,
    );
    final sanitized = prepared.input;
    final anonymous = shareAnonymously || prepared.requiresAnonymousSharing;

    final trimmedQuestion = sanitized.question?.trim() ?? question.trim();
    final trimmedResponse = sanitized.response?.trim() ?? response.trim();
    final trimmedTitle = sanitized.title?.trim() ?? title.trim();
    final trimmedNote = sanitized.personalNote?.trim();
    if (trimmedQuestion.isEmpty || trimmedResponse.isEmpty) return false;
    final docId = _journeyDocId(
      question: trimmedQuestion,
      response: trimmedResponse,
      linkedActivityId: linkedActivityId,
    );

    final docRef = _journeys.doc(docId);
    final existing = await docRef.get();
    if (existing.exists) return false;

    final journey = WalkTogetherJourney(
      id: docId,
      title: trimmedTitle.isNotEmpty ? trimmedTitle : 'Shared Journey',
      question: trimmedQuestion,
      response: trimmedResponse,
      createdAt: DateTime.now(),
      createdByUid: user.uid,
      shareType: shareType ?? 'reflection',
      linkedActivityId: linkedActivityId,
      personalNote: trimmedNote?.isEmpty == true ? null : trimmedNote,
      shareAnonymously: anonymous,
      sharedByDisplayName:
          anonymous ? null : sharedByDisplayName?.trim(),
      favoriteSaint: anonymous ? null : favoriteSaint?.trim(),
    );

    await docRef.set(journey.toMap());
    return true;
  }

  /// Shares a Kingdom Challenge / Gift inside WWJD-DI (Walk Together feed).
  Future<bool> addGiftJourney(GiftSharePayload payload) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to share inside WWJD-DI.');
    }

    final prepared = sharedContentGate.processSilently(
      SharedContentInput(
        title: payload.title,
        question: 'Kingdom Challenge: ${payload.title.trim()}',
        response: payload.activityBody,
        personalNote: payload.personalNote,
      ),
      channel: SharedContentChannel.walkTogether,
    );
    final sanitized = prepared.input;

    final shareTitle = sanitized.title?.trim() ?? payload.title.trim();
    final trimmedQuestion =
        sanitized.question?.trim() ?? 'Kingdom Challenge: $shareTitle';
    final trimmedResponse =
        sanitized.response?.trim() ?? payload.activityBody.trim();
    if (shareTitle.isEmpty || trimmedResponse.isEmpty) return false;
    final docId = _journeyDocId(
      question: trimmedQuestion,
      response: trimmedResponse,
      linkedActivityId: payload.linkedActivityId,
    );

    final docRef = _journeys.doc(docId);
    final existing = await docRef.get();
    if (existing.exists) return false;

    final now = DateTime.now();
    final journeyMap = WalkTogetherGiftShare.journeyMapFromPayload(
      payload,
      createdByUid: user.uid,
      createdAt: now,
    );
    journeyMap['title'] = shareTitle;
    journeyMap['question'] = trimmedQuestion;
    journeyMap['response'] = trimmedResponse;
    if (sanitized.personalNote != null) {
      journeyMap['personalNote'] = sanitized.personalNote!.trim().isEmpty
          ? null
          : sanitized.personalNote!.trim();
    }
    if (prepared.requiresAnonymousSharing) {
      journeyMap['shareAnonymously'] = true;
      journeyMap['sharedByDisplayName'] = null;
      journeyMap['favoriteSaint'] = null;
    }

    await docRef.set(journeyMap);
    return true;
  }

  Future<void> upvote(String journeyId) async {
    if (_auth.currentUser == null) {
      throw Exception('Sign in to upvote journeys.');
    }

    await _journeys.doc(journeyId).update({
      'upvotes': FieldValue.increment(1),
    });
  }

  /// Deletes a journey when the current user is [createdByUid].
  Future<void> deleteJourney(String journeyId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to delete journeys.');
    }

    final doc = await _journeys.doc(journeyId).get();
    if (!doc.exists) return;

    final createdByUid = doc.data()?['createdByUid']?.toString();
    if (createdByUid != user.uid) {
      throw Exception('You can only delete journeys you shared.');
    }

    await _journeys.doc(journeyId).delete();
  }

  bool canDeleteJourney(WalkTogetherJourney journey) {
    final uid = _auth.currentUser?.uid;
    return uid != null &&
        journey.createdByUid != null &&
        journey.createdByUid == uid;
  }

  Future<WalkTogetherJourney?> getJourney(String journeyId) async {
    final doc = await _journeys.doc(journeyId.trim()).get();
    if (!doc.exists || doc.data() == null) return null;
    return WalkTogetherJourney.fromMap(doc.id, doc.data()!);
  }

  static String _journeyDocId({
    required String question,
    required String response,
    String? linkedActivityId,
  }) {
    if (linkedActivityId != null && linkedActivityId.isNotEmpty) {
      return linkedActivityId;
    }

    final normalized = '${question.trim()}\n---\n${response.trim()}';
    final digest = base64Url
        .encode(utf8.encode(normalized))
        .replaceAll('=', '')
        .replaceAll('/', '_');
    return 'j_${digest.length > 128 ? digest.substring(0, 128) : digest}';
  }
}
