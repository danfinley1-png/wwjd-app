import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/walk_together_engagement.dart';

class WalkTogetherEngagementService {
  WalkTogetherEngagementService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const fieldKey = 'walkTogetherEngagement';

  DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return _firestore.collection('users').doc(uid);
  }

  Stream<WalkTogetherEngagement> watchEngagement() {
    final doc = _userDoc();
    if (doc == null) {
      return Stream.value(WalkTogetherEngagement.empty);
    }

    return doc.snapshots().map((snap) {
      final raw = snap.data()?[fieldKey];
      if (raw is Map<String, dynamic>) {
        return WalkTogetherEngagement.fromMap(raw);
      }
      return WalkTogetherEngagement.empty;
    });
  }

  Future<void> toggleSaved(String journeyId) async {
    final doc = _userDoc();
    if (doc == null) {
      throw Exception('Sign in to save Walk Together posts.');
    }

    final snap = await doc.get();
    final engagement = WalkTogetherEngagement.fromMap(
      snap.data()?[fieldKey] as Map<String, dynamic>?,
    );

    await doc.set(
      {
        '$fieldKey.savedIds': engagement.isSaved(journeyId)
            ? FieldValue.arrayRemove([journeyId])
            : FieldValue.arrayUnion([journeyId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> markRead(String journeyId) async {
    final doc = _userDoc();
    if (doc == null) return;

    await doc.set(
      {
        '$fieldKey.readIds': FieldValue.arrayUnion([journeyId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setHideRead(bool hideRead) async {
    final doc = _userDoc();
    if (doc == null) {
      throw Exception('Sign in to save feed preferences.');
    }

    await doc.set(
      {
        '$fieldKey.hideRead': hideRead,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
