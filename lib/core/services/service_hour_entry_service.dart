import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../admin/models/service_hours.dart';
import '../firestore_auth_retry.dart';

/// Member writes for [ServiceHourEntry]. Never stores reflection body.
class ServiceHourEntryService {
  ServiceHourEntryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _entries =>
      _firestore.collection(ServiceHourEntry.collection);

  /// Owner-scoped list. Query must include [userId] so rules can allow it.
  Stream<List<ServiceHourEntry>> watchMine() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    return firestoreSnapshotsRetrying(
      auth: _auth,
      snapshots: () => _entries
          .where('userId', isEqualTo: uid)
          .orderBy('date', descending: true)
          .snapshots(),
    ).map((snap) {
      final items = snap.docs
          .map((doc) => ServiceHourEntry.fromMap(doc.id, doc.data()))
          .toList();
      items.sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        return b.submittedAt.compareTo(a.submittedAt);
      });
      return items;
    });
  }

  Stream<List<ServiceHourEntry>> watchMineForProject(String projectId) {
    final wanted = projectId.trim();
    if (wanted.isEmpty) return Stream.value(const []);
    return watchMine().map(
      (items) => items.where((entry) => entry.projectId == wanted).toList(),
    );
  }

  Future<String> createEntry({
    required ServiceProject project,
    required DateTime date,
    required double hours,
    String note = '',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to log service hours.');
    }

    final day = DateTime(date.year, date.month, date.day);
    final snapped = ServiceHourEntry.snapHours(hours);
    final error = ServiceHourEntryValidation.validate(
      project: project,
      date: day,
      hours: snapped,
      note: note,
    );
    if (error != null) throw StateError(error);

    final now = DateTime.now();
    final entry = ServiceHourEntry(
      id: '',
      projectId: project.id,
      orgId: project.orgId,
      userId: uid,
      date: day,
      hours: snapped,
      note: note.trim(),
      status: project.initialEntryStatus,
      submittedAt: now,
      source: project.source,
    );

    final doc = _entries.doc();
    await doc.set(entry.toMap(includeReflectionId: false));
    return doc.id;
  }

  Future<void> updateEntry({
    required ServiceProject project,
    required ServiceHourEntry existing,
    required DateTime date,
    required double hours,
    String note = '',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid != existing.userId) {
      throw StateError('Only the person who logged these hours can edit them.');
    }
    if (!existing.isOwnerEditable) {
      throw StateError('Approved hours cannot be edited.');
    }

    final day = DateTime(date.year, date.month, date.day);
    final snapped = ServiceHourEntry.snapHours(hours);
    final error = ServiceHourEntryValidation.validate(
      project: project,
      date: day,
      hours: snapped,
      note: note,
    );
    if (error != null) throw StateError(error);

    final updated = existing.copyWith(
      date: day,
      hours: snapped,
      note: note.trim(),
    );
    await _entries.doc(existing.id).set(
          updated.toMap(includeReflectionId: existing.hasReflection),
        );
  }

  Future<void> deleteEntry(ServiceHourEntry existing) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid != existing.userId) {
      throw StateError('Only the person who logged these hours can delete them.');
    }
    if (!existing.isOwnerEditable) {
      throw StateError('Approved hours cannot be deleted.');
    }
    await _entries.doc(existing.id).delete();
  }

  Future<void> attachReflectionId({
    required String entryId,
    required String reflectionId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to link a private reflection.');
    }
    final id = reflectionId.trim();
    if (id.isEmpty) {
      throw StateError('A reflection id is required.');
    }
    final snap = await _entries.doc(entryId).get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('Hour entry not found.');
    }
    if (data['userId'] != uid) {
      throw StateError('Only the owner can link a private reflection.');
    }
    await snap.reference.update({'reflectionId': id});
  }
}
