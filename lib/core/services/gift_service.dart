// lib/core/services/gift_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/gift_activity.dart';
import '../../models/gift_status.dart';
import '../gift_tracking.dart';
import '../catholic_prayers/prayer_gift_link.dart';
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
      return snap.docs.map((doc) => _fromDoc(doc)).toList();
    });
  }

  /// One-time load
  Future<List<GiftActivity>> getUserGifts() async {
    final col = _userGifts;
    if (col == null) return [];

    final snap = await col.orderBy('createdAt', descending: true).get();
    return snap.docs.map((doc) => _fromDoc(doc)).toList();
  }

  GiftActivity _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    data['id'] = doc.id;
    return GiftActivity.fromMap(data);
  }

  List<GiftActivity> getActiveGifts(List<GiftActivity> gifts) {
    return GiftTracking.activeGifts(gifts);
  }

  List<GiftActivity> getTodayGifts(List<GiftActivity> gifts, [DateTime? now]) {
    return GiftTracking.todayGifts(gifts, now);
  }

  List<GiftActivity> getTodaySectionGifts(List<GiftActivity> gifts, [DateTime? now]) {
    return GiftTracking.todaySectionGifts(gifts, now);
  }

  GiftAggregateStats getAggregateStats(List<GiftActivity> gifts) {
    return GiftTracking.aggregateStats(gifts);
  }

  /// True when [candidate] matches an existing gift by title or description.
  bool isDuplicateGift(GiftActivity candidate, GiftActivity existing) {
    final titleA = candidate.title.trim().toLowerCase();
    final titleB = existing.title.trim().toLowerCase();
    if (titleA.isNotEmpty && titleA == titleB) return true;

    final descA = candidate.description.trim().toLowerCase();
    final descB = existing.description.trim().toLowerCase();
    if (descA.length >= 20 && descA == descB) return true;

    return false;
  }

  GiftActivity? findDuplicate(
    GiftActivity candidate,
    List<GiftActivity> existing,
  ) {
    for (final gift in existing) {
      if (isDuplicateGift(candidate, gift)) return gift;
    }
    return null;
  }

  /// Saves gifts, skipping duplicates. Returns counts of added vs skipped items.
  Future<({int added, int skipped})> saveGiftsSkippingDuplicates(
    List<GiftActivity> activities,
  ) async {
    if (activities.isEmpty) return (added: 0, skipped: 0);

    final existing = await getUserGifts();
    var added = 0;
    var skipped = 0;

    for (final activity in activities) {
      if (findDuplicate(activity, existing) != null) {
        skipped++;
        continue;
      }
      await saveGift(activity);
      existing.add(activity);
      added++;
    }

    return (added: added, skipped: skipped);
  }

  Future<void> saveGift(GiftActivity activity) async {
    final col = _userGifts;
    if (col == null) return;

    final enriched = PrayerGiftLink.enrich(activity);
    final data = enriched.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (data['createdAt'] == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await col.doc(activity.id).set(data, SetOptions(merge: true));
  }

  /// Marks a gift complete for its frequency period (day / week / month).
  /// Returns the updated gift, or null if already completed in that period.
  Future<GiftActivity?> completeGiftForToday(GiftActivity activity) async {
    if (GiftTracking.isCompletedInPeriod(activity)) {
      return null;
    }

    final updated = GiftTracking.applyCompletion(activity);
    await saveGift(updated);
    return updated;
  }

  Future<void> setGiftStatus(GiftActivity activity, GiftStatus status) async {
    final updated = activity.copyWith(
      status: status,
      isCompleted: status == GiftStatus.completed,
    );
    await saveGift(updated);
  }

  Future<void> deleteGift(String activityId) async {
    final col = _userGifts;
    if (col == null) return;
    await col.doc(activityId).delete();
  }

  /// Removes the gift and restores its source conversation to My History when missing.
  /// Returns true when new history entries were written.
  Future<bool> moveToHistory(
    GiftActivity activity,
    HistoryService historyService,
  ) async {
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
    } on FirebaseException catch (e) {
      // Guest gift docs belong to the previous anonymous uid; after sign-in
      // they are unreadable. Do not fail the new session.
      print('GiftService.migrateGuestGifts skipped: ${e.code} ${e.message}');
      return 0;
    } catch (e) {
      print('GiftService.migrateGuestGifts error: $e');
      return 0;
    }
  }

  /// Legacy toggle — for one-time gifts toggles completed status;
  /// for recurring gifts delegates to [completeGiftForToday].
  Future<void> toggleComplete(GiftActivity activity) async {
    if (GiftTracking.isOneTime(activity)) {
      final nextStatus = activity.status == GiftStatus.completed
          ? GiftStatus.active
          : GiftStatus.completed;
      if (nextStatus == GiftStatus.completed) {
        await completeGiftForToday(activity);
      } else {
        await saveGift(
          activity.copyWith(
            status: GiftStatus.active,
            isCompleted: false,
            completionDates: [],
            totalCompletions: 0,
            currentStreak: 0,
            lastCompleted: null,
            completedAt: null,
          ),
        );
      }
      return;
    }

    if (GiftTracking.isCompletedInPeriod(activity)) {
      return;
    }
    await completeGiftForToday(activity);
  }
}
