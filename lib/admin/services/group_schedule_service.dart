import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group_schedule.dart';
import '../models/ministry_group.dart';
import '../models/organization_membership.dart';
import '../../core/catholic_prayers/prayer_gift_link.dart';
import '../../core/prayer_link.dart';

/// Creates and syncs group schedules to accepted members only.
class GroupScheduleService {
  GroupScheduleService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _schedules(String orgId, String groupId) =>
      _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('groups')
          .doc(groupId)
          .collection('schedules');

  CollectionReference<Map<String, dynamic>>? _userPractices(String uid) =>
      _firestore.collection('users').doc(uid).collection('groupPractices');

  Stream<List<GroupSchedule>> watchSchedules({
    required String orgId,
    required String groupId,
  }) {
    return _schedules(orgId, groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => GroupSchedule.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> createSchedule({
    required String orgId,
    required MinistryGroup group,
    required String organizationName,
    required String title,
    required String description,
    required List<String> times,
    required GroupScheduleRecurrence recurrence,
    List<String> daysOfWeek = const [],
    String? practiceText,
    String? practiceLink,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Sign in required.');

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) throw Exception('Title is required.');
    if (times.isEmpty) throw Exception('Add at least one daily time.');

    final resolvedPracticeLink = practiceLink?.trim().isNotEmpty == true
        ? practiceLink!.trim()
        : _defaultPrayerLink(trimmedTitle, description);

    final ref = _schedules(orgId, group.id).doc();
    final schedule = GroupSchedule(
      id: ref.id,
      organizationId: orgId,
      groupId: group.id,
      groupName: group.name,
      organizationName: organizationName,
      title: trimmedTitle,
      description: description.trim(),
      practiceText: practiceText,
      practiceLink: resolvedPracticeLink,
      times: times,
      recurrence: recurrence,
      daysOfWeek: daysOfWeek,
      createdByUid: uid,
      createdAt: DateTime.now(),
    );

    await ref.set(schedule.toMap());
    await _syncScheduleToAcceptedMembers(schedule);
    return ref.id;
  }

  Future<void> deactivateSchedule({
    required String orgId,
    required String groupId,
    required String scheduleId,
  }) async {
    await _schedules(orgId, groupId).doc(scheduleId).update({'active': false});
    final members = await _acceptedMembers(orgId, groupId);
    final batch = _firestore.batch();
    for (final member in members) {
      batch.set(
        _userPractices(member.uid)!.doc(scheduleId),
        {'active': false, 'syncedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Called when a user accepts group membership — deliver active schedules.
  Future<void> syncSchedulesForNewMember({
    required String orgId,
    required String groupId,
    required String memberUid,
  }) async {
    final snap = await _schedules(orgId, groupId)
        .where('active', isEqualTo: true)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      final schedule = GroupSchedule.fromMap(doc.id, doc.data());
      batch.set(
        _userPractices(memberUid)!.doc(schedule.id),
        _practicePayload(schedule),
      );
    }
    await batch.commit();
  }

  /// Removes synced practices when a member leaves a group.
  Future<void> removePracticesForMember({
    required String orgId,
    required String groupId,
    required String memberUid,
  }) async {
    final snap = await _userPractices(memberUid)!
        .where('groupId', isEqualTo: groupId)
        .where('organizationId', isEqualTo: orgId)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _syncScheduleToAcceptedMembers(GroupSchedule schedule) async {
    final members = await _acceptedMembers(schedule.organizationId, schedule.groupId);
    if (members.isEmpty) return;

    var batch = _firestore.batch();
    var ops = 0;

    for (final member in members) {
      batch.set(
        _userPractices(member.uid)!.doc(schedule.id),
        _practicePayload(schedule),
      );
      ops++;
      if (ops >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
  }

  Map<String, dynamic> _practicePayload(GroupSchedule schedule) {
    return {
      'groupScheduleId': schedule.id,
      'organizationId': schedule.organizationId,
      'groupId': schedule.groupId,
      if (schedule.groupName != null) 'groupName': schedule.groupName,
      if (schedule.organizationName != null)
        'organizationName': schedule.organizationName,
      'title': schedule.title,
      'description': schedule.description,
      if (schedule.practiceText != null && schedule.practiceText!.trim().isNotEmpty)
        'practiceText': schedule.practiceText!.trim(),
      if (schedule.practiceLink != null && schedule.practiceLink!.trim().isNotEmpty)
        'practiceLink': schedule.practiceLink!.trim(),
      'times': schedule.times,
      'recurrence': schedule.recurrence.firestoreValue,
      'daysOfWeek': schedule.daysOfWeek,
      'active': schedule.active,
      'source': 'groupSchedule',
      'syncedAt': FieldValue.serverTimestamp(),
      'completionSlots': <String>[],
    };
  }

  Future<List<OrganizationMembership>> _acceptedMembers(
    String orgId,
    String groupId,
  ) async {
    final snap = await _firestore
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .get();
    return snap.docs
        .map((doc) => OrganizationMembership.fromMap(doc.id, doc.data()))
        .where((m) => m.groupIds.contains(groupId))
        .toList();
  }

  String? _defaultPrayerLink(String title, String description) {
    final prayerId = PrayerGiftLink.detectPrayerId(
      title: title,
      description: description,
    );
    return prayerId == null ? null : PrayerLink.url(prayerId);
  }
}
