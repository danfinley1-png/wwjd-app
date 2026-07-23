// lib/core/services/gift_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/gift_activity.dart';
import 'history_service.dart';

class GiftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? get _userGifts {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('gifts');
  }

  /// Real-time stream of user's gifts
  Stream<List<GiftActivity>> getUserGiftsStream() {
    final col = _userGifts;
    if (col == null) return Stream.value([]);

    return col.orderBy('createdAt', descending: true).snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // ensure id is present
        return GiftActivity.fromMap(data);
      }).toList();
    });
  }

  /// One-time load
  Future<List<GiftActivity>> getUserGifts() async {
    final col = _userGifts;
    if (col == null) return [];

    final snap = await col.orderBy('createdAt', descending: true).get();
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return GiftActivity.fromMap(data);
    }).toList();
  }

  Future<void> saveGift(GiftActivity activity) async {
    final col = _userGifts;
    if (col == null) return;

    final data = activity.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (data['createdAt'] == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await col.doc(activity.id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteGift(String activityId) async {
    final col = _userGifts;
    if (col == null) return;
    await col.doc(activityId).delete();
  }

  /// Removes the gift and restores its source conversation to My History when missing.
  /// Returns true when new history entries were written.
  Future<bool> moveToHistory(GiftActivity activity, HistoryService historyService) async {
    final question = _historyQuestionFor(activity);
    final response = _historyResponseFor(activity);
    final added = await historyService.restoreGiftToHistory(
      question: question,
      response: response,
    );
    await deleteGift(activity.id);
    return added;
  }

  String _historyQuestionFor(GiftActivity activity) {
    final linked = activity.linkedQuestionText?.trim();
    if (linked != null && linked.isNotEmpty) return linked;
    return 'Gift activity: ${activity.title}';
  }

  String _historyResponseFor(GiftActivity activity) {
    final linked = activity.linkedResponseText?.trim();
    if (linked != null && linked.isNotEmpty) {
      return _appendGiftNote(linked, activity);
    }

    final buffer = StringBuffer(activity.description.trim());
    if (activity.note != null && activity.note!.trim().isNotEmpty) {
      buffer.writeln('\n\n**Note:** ${activity.note!.trim()}');
    }
    buffer.writeln('\n\n*Moved from Sharing My Gifts*');
    return buffer.toString();
  }

  String _appendGiftNote(String response, GiftActivity activity) {
    if (activity.note == null || activity.note!.trim().isEmpty) return response;
    return '$response\n\n**Gift note:** ${activity.note!.trim()}';
  }

  /// Copy gifts from a guest/anonymous UID into the current signed-in user.
  Future<int> migrateGuestGifts(String fromUid) async {
    final toUid = _auth.currentUser?.uid;
    if (toUid == null || fromUid.isEmpty || fromUid == toUid) return 0;

    try {
      final fromCol =
          _firestore.collection('users').doc(fromUid).collection('gifts');
      final snap = await fromCol.get();
      if (snap.docs.isEmpty) return 0;

      final toCol = _firestore.collection('users').doc(toUid).collection('gifts');
      var count = 0;

      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['userId'] = toUid;
        data['updatedAt'] = FieldValue.serverTimestamp();
        await toCol.doc(doc.id).set(data, SetOptions(merge: true));
        count++;
      }
      return count;
    } catch (e) {
      print('GiftService.migrateGuestGifts error: $e');
      rethrow;
    }
  }

  Future<void> toggleComplete(GiftActivity activity) async {
    final updated = GiftActivity(
      id: activity.id,
      title: activity.title,
      description: activity.description,
      linkedQuestionId: activity.linkedQuestionId,
      linkedQuestionText: activity.linkedQuestionText,
      linkedResponseText: activity.linkedResponseText,
      frequency: activity.frequency,
      specificTime: activity.specificTime,
      daysOfWeek: activity.daysOfWeek,
      dueDate: activity.dueDate,
      isCompleted: !activity.isCompleted,
      note: activity.note,
      completedAt: !activity.isCompleted ? DateTime.now() : null,
      hasReminder: activity.hasReminder,
      userId: activity.userId,
    );
    await saveGift(updated);
  }
}