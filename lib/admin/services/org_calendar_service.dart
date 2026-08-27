import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_role.dart';
import '../models/org_calendar_event.dart';
import '../models/org_calendar_schedule.dart';

/// School / organization schedule template.
///
/// Does not read or write Seeking God’s Wisdom, Reflections, History, or Gifts.
class OrgCalendarService {
  OrgCalendarService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _scheduleDoc(String orgId) =>
      _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('calendarSchedules')
          .doc(OrgCalendarSchedule.defaultDocId);

  CollectionReference<Map<String, dynamic>> _events(String orgId) =>
      _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('calendarEvents');

  /// Admin: persisted template, or a draft imported from earlier dated events.
  Stream<OrgCalendarSchedule> watchScheduleForAdmin(String orgId) {
    return _scheduleDoc(orgId).snapshots().asyncMap((snap) async {
      if (snap.exists && snap.data() != null) {
        return OrgCalendarSchedule.fromMap(snap.id, snap.data()!);
      }
      final events = await _loadEventsForAdmin(orgId);
      if (events.isEmpty) {
        return OrgCalendarSchedule.empty(orgId, createdByUid: _uid ?? '');
      }
      return OrgCalendarSchedule.fromEvents(
        orgId: orgId,
        events: events,
        createdByUid: _uid ?? '',
      );
    });
  }

  /// Members: the shared template if they may read it.
  Stream<OrgCalendarSchedule> watchScheduleForMember({
    required String orgId,
    List<String> groupIds = const [],
  }) {
    late StreamController<OrgCalendarSchedule> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
    controller = StreamController<OrgCalendarSchedule>(
      onListen: () {
        sub = _scheduleDoc(orgId).snapshots().listen(
          (snap) async {
            try {
              if (snap.exists && snap.data() != null) {
                if (!controller.isClosed) {
                  controller.add(
                    OrgCalendarSchedule.fromMap(snap.id, snap.data()!),
                  );
                }
                return;
              }
              final events = await _loadVisibleEvents(orgId, groupIds);
              if (controller.isClosed) return;
              if (events.isEmpty) {
                controller.add(OrgCalendarSchedule.empty(orgId));
              } else {
                controller.add(
                  OrgCalendarSchedule.fromEvents(orgId: orgId, events: events),
                );
              }
            } catch (_) {
              if (!controller.isClosed) {
                controller.add(OrgCalendarSchedule.empty(orgId));
              }
            }
          },
          onError: (_) {
            if (!controller.isClosed) {
              controller.add(OrgCalendarSchedule.empty(orgId));
            }
          },
        );
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  Future<List<OrgCalendarEvent>> _loadVisibleEvents(
    String orgId,
    List<String> groupIds,
  ) async {
    try {
      final orgWide = await _events(orgId)
          .where(
            'visibility',
            isEqualTo: OrgCalendarVisibility.organization.firestoreValue,
          )
          .orderBy('startAt')
          .get();
      final byId = <String, OrgCalendarEvent>{
        for (final doc in orgWide.docs)
          doc.id: OrgCalendarEvent.fromMap(doc.id, doc.data()),
      };
      final unique = groupIds.toSet().toList();
      for (var i = 0; i < unique.length; i += 10) {
        final end = i + 10 > unique.length ? unique.length : i + 10;
        final chunk = unique.sublist(i, end);
        final groupSnap = await _events(orgId)
            .where(
              'visibility',
              isEqualTo: OrgCalendarVisibility.groups.firestoreValue,
            )
            .where('groupIds', arrayContainsAny: chunk)
            .orderBy('startAt')
            .get();
        for (final doc in groupSnap.docs) {
          byId[doc.id] = OrgCalendarEvent.fromMap(doc.id, doc.data());
        }
      }
      final list = byId.values.toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSchedule(OrgCalendarSchedule schedule) async {
    await _assertCanManage(schedule.organizationId);
    final uid = _uid!;
    for (final row in schedule.rows) {
      if (row.isBlank) continue;
      if (!row.isComplete) {
        throw Exception(
          'Each row needs an activity and a When (for example “Tuesdays during lunch”).',
        );
      }
      if (row.title.trim().length > OrgScheduleRow.titleMax ||
          row.whenText.trim().length > OrgScheduleRow.whenMax) {
        throw Exception('Title and When must be ${OrgScheduleRow.titleMax} characters or fewer.');
      }
      if (row.location.trim().length > OrgScheduleRow.locationMax) {
        throw Exception('Location is too long.');
      }
      if (row.notes.trim().length > OrgScheduleRow.notesMax) {
        throw Exception('Notes are too long.');
      }
    }
    if (schedule.visibility == OrgCalendarVisibility.groups &&
        schedule.groupIds.isEmpty) {
      throw Exception(
        'Select at least one group, or share with the whole organization.',
      );
    }
    final readyCount = schedule.rows.where((r) => !r.isBlank).length;
    if (readyCount > OrgCalendarSchedule.maxRows) {
      throw Exception(
        'This template allows up to ${OrgCalendarSchedule.maxRows} rows.',
      );
    }

    final existing = await _scheduleDoc(schedule.organizationId).get();
    final createdByUid = existing.data()?['createdByUid'] as String? ?? uid;
    final createdAt = existing.data()?['createdAt'] is Timestamp
        ? (existing.data()!['createdAt'] as Timestamp).toDate()
        : schedule.createdAt;

    final toSave = schedule.copyWith(createdByUid: createdByUid);
    final payload = toSave.toMap(updatedByUid: uid);
    payload['createdByUid'] = createdByUid;
    payload['createdAt'] = Timestamp.fromDate(createdAt);

    await _scheduleDoc(schedule.organizationId).set(payload);
  }

  Future<List<OrgCalendarEvent>> _loadEventsForAdmin(String orgId) async {
    try {
      final snap = await _events(orgId).orderBy('startAt').get();
      return snap.docs
          .map((doc) => OrgCalendarEvent.fromMap(doc.id, doc.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _assertCanManage(String orgId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Sign in required.');
    if (await _canManageCalendar(orgId)) return;
    throw Exception(
      'Only organization administrators can edit the school schedule.',
    );
  }

  Future<bool> _canManageCalendar(String orgId) async {
    final uid = _uid;
    if (uid == null) return false;

    final platformAdmin =
        await _firestore.collection('platformAdmins').doc(uid).get();
    if (platformAdmin.exists) return true;

    final org = await _firestore.collection('organizations').doc(orgId).get();
    if (org.data()?['createdByUid'] == uid) return true;

    final member = await _firestore
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(uid)
        .get();
    final role = adminRoleFromFirestore(member.data()?['role'] as String?);
    return role.canManageOrgCalendar;
  }
}
