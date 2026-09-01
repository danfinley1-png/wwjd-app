import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firestore_auth_retry.dart';
import '../group_practice_tracking.dart';
import '../../models/group_practice_instance.dart';

/// Member-facing group practice reads and completions.
class GroupPracticeService {
  GroupPracticeService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>? get _practices {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('groupPractices');
  }

  Stream<List<GroupPracticeInstance>> watchGroupPractices() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return watchGroupPracticesForUid(uid);
  }

  Stream<List<GroupPracticeInstance>> watchGroupPracticesForUid(String uid) {
    final query = _firestore
        .collection('users')
        .doc(uid)
        .collection('groupPractices')
        .orderBy('syncedAt', descending: true);

    return firestoreSnapshotsRetrying(
      auth: _auth,
      snapshots: () => query.snapshots(),
    ).map(
      (snap) => snap.docs
          .map((doc) => GroupPracticeInstance.fromMap(doc.id, doc.data()))
          .where((p) => p.active)
          .toList(),
    );
  }

  Future<List<GroupPracticeInstance>> getGroupPractices() async {
    final col = _practices;
    if (col == null) return [];

    final snap = await col.get();
    return snap.docs
        .map((doc) => GroupPracticeInstance.fromMap(doc.id, doc.data()))
        .where((p) => p.active)
        .toList();
  }

  List<GroupPracticeInstance> getDueToday(List<GroupPracticeInstance> practices) {
    return GroupPracticeTracking.dueToday(practices);
  }

  Future<GroupPracticeInstance?> completeNextSlot(
    GroupPracticeInstance practice,
  ) async {
    final col = _practices;
    if (col == null) return null;

    final updated = GroupPracticeTracking.markNextSlotComplete(practice);
    if (updated.completionSlots.length == practice.completionSlots.length) {
      return null;
    }

    await col.doc(practice.id).update({
      'completionSlots': updated.completionSlots,
      'lastCompleted': Timestamp.fromDate(updated.lastCompleted ?? DateTime.now()),
      'totalCompletions': updated.totalCompletions,
      'currentStreak': updated.currentStreak,
    });
    return updated;
  }
}
