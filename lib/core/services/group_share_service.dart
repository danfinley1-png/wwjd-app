import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../content_guidance/content_guidance_models.dart';
import '../content_guidance/shared_content_gate.dart';
import '../gift_share_payload.dart';
import '../models/shareable_group.dart';

/// Posts anonymized / attributed shares into a ministry group feed.
class GroupShareService {
  GroupShareService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> _groupShares(
    String orgId,
    String groupId,
  ) =>
      _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('groups')
          .doc(groupId)
          .collection('shares');

  Future<bool> shareReflection({
    required ShareableGroup group,
    required String title,
    required String question,
    required String response,
    bool shareAnonymously = true,
    String? sharedByDisplayName,
    String? favoriteSaint,
    String? personalNote,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to share to a group.');
    }

    final prepared = sharedContentGate.processSilently(
      SharedContentInput(
        title: title,
        question: question,
        response: response,
        personalNote: personalNote,
      ),
      channel: SharedContentChannel.groupShare,
    );
    final sanitized = prepared.input;
    final anonymous = shareAnonymously || prepared.requiresAnonymousSharing;

    final trimmedQuestion = sanitized.question?.trim() ?? question.trim();
    final trimmedResponse = sanitized.response?.trim() ?? response.trim();
    final trimmedTitle = sanitized.title?.trim() ?? title.trim();
    if (trimmedQuestion.isEmpty || trimmedResponse.isEmpty) return false;

    final shareId = _uuid.v4();
    await _groupShares(group.organizationId, group.groupId).doc(shareId).set({
      'organizationId': group.organizationId,
      'groupId': group.groupId,
      'groupName': group.groupName,
      'organizationName': group.organizationName,
      'shareType': 'reflection',
      'title': trimmedTitle.isNotEmpty ? trimmedTitle : 'Shared reflection',
      'question': trimmedQuestion,
      'response': trimmedResponse,
      'personalNote': sanitized.personalNote?.trim().isEmpty == true
          ? null
          : sanitized.personalNote?.trim(),
      'shareAnonymously': anonymous,
      'sharedByDisplayName':
          anonymous ? null : sharedByDisplayName?.trim(),
      'favoriteSaint': anonymous ? null : favoriteSaint?.trim(),
      'createdByUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'brand': GiftSharePayload.brandName,
    });
    return true;
  }

  Future<bool> shareGift({
    required ShareableGroup group,
    required GiftSharePayload payload,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to share to a group.');
    }

    final prepared = sharedContentGate.processSilently(
      SharedContentInput(
        title: payload.title,
        question: 'Kingdom Challenge: ${payload.title.trim()}',
        response: payload.activityBody,
        personalNote: payload.personalNote,
      ),
      channel: SharedContentChannel.groupShare,
    );
    final sanitized = prepared.input;
    final anonymous =
        payload.shareAnonymously || prepared.requiresAnonymousSharing;

    final shareTitle = sanitized.title?.trim() ?? payload.title.trim();
    final trimmedResponse =
        sanitized.response?.trim() ?? payload.activityBody.trim();
    if (shareTitle.isEmpty || trimmedResponse.isEmpty) return false;

    final shareId = _uuid.v4();
    await _groupShares(group.organizationId, group.groupId).doc(shareId).set({
      'organizationId': group.organizationId,
      'groupId': group.groupId,
      'groupName': group.groupName,
      'organizationName': group.organizationName,
      'shareType': 'gift',
      'title': shareTitle,
      'question': sanitized.question?.trim() ??
          'Kingdom Challenge: $shareTitle',
      'response': trimmedResponse,
      'personalNote': sanitized.personalNote?.trim().isEmpty == true
          ? null
          : sanitized.personalNote?.trim(),
      'shareAnonymously': anonymous,
      'sharedByDisplayName':
          anonymous ? null : payload.displayName?.trim(),
      'favoriteSaint': anonymous ? null : payload.favoriteSaint?.trim(),
      'linkedActivityId': payload.linkedActivityId,
      if (payload.linkedPrayerId != null &&
          payload.linkedPrayerId!.trim().isNotEmpty)
        'linkedPrayerId': payload.linkedPrayerId!.trim(),
      'createdByUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'brand': GiftSharePayload.brandName,
    });
    return true;
  }
}
