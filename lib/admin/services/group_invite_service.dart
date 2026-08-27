import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';



import '../../core/models/shareable_group.dart';

import '../../core/services/user_groups_service.dart';

import '../models/group_membership_invite.dart';

import '../models/organization_membership.dart';

import 'group_gift_service.dart';
import 'group_schedule_service.dart';

import 'organization_service.dart';



/// Consent-based group membership invitations.

class GroupInviteService {

  GroupInviteService({

    FirebaseFirestore? firestore,

    FirebaseAuth? auth,

    Uuid? uuid,

  })  : _firestore = firestore ?? FirebaseFirestore.instance,

        _auth = auth ?? FirebaseAuth.instance,

        _uuid = uuid ?? const Uuid();



  final FirebaseFirestore _firestore;

  final FirebaseAuth _auth;

  final Uuid _uuid;

  final UserGroupsService _userGroupsService = UserGroupsService();

  final GroupScheduleService _groupScheduleService = GroupScheduleService();

  final GroupGiftService _groupGiftService = GroupGiftService();

  final OrganizationService _organizationService = OrganizationService();



  String? get _uid => _auth.currentUser?.uid;



  CollectionReference<Map<String, dynamic>> _groupInvites(String orgId) =>

      _firestore.collection('organizations').doc(orgId).collection('groupInvites');



  CollectionReference<Map<String, dynamic>>? _userGroupInviteIndex(String uid) =>

      _firestore.collection('users').doc(uid).collection('pendingGroupInvites');



  /// Invites an existing org member to a group — does not add them directly.

  Future<void> inviteMemberToGroup({

    required String orgId,

    required OrganizationMembership member,

    required String groupId,

    required String groupName,

    String? organizationName,

  }) async {

    final uid = _uid;

    if (uid == null) throw Exception('Sign in required.');



    await _organizationService.ensureCanSendGroupInvite(orgId);



    if (member.groupIds.contains(groupId)) {

      throw Exception('Member is already in this group.');

    }



    final pending = await _groupInvites(orgId)

        .where('inviteeUid', isEqualTo: member.uid)

        .where('groupId', isEqualTo: groupId)

        .where('status', isEqualTo: GroupInviteStatus.pending.firestoreValue)

        .limit(1)

        .get();

    if (pending.docs.isNotEmpty) {

      throw Exception('A pending invitation already exists for this group.');

    }



    final inviteId = _uuid.v4();

    final now = DateTime.now();

    final invite = GroupMembershipInvite(

      id: inviteId,

      organizationId: orgId,

      groupId: groupId,

      groupName: groupName,

      inviteeUid: member.uid,
      inviteeEmail: OrganizationService.normalizeEmail(member.email ?? ''),

      invitedByUid: uid,

      status: GroupInviteStatus.pending,

      createdAt: now,

      organizationName: organizationName,

    );



    final batch = _firestore.batch();

    batch.set(_groupInvites(orgId).doc(inviteId), invite.toMap());

    batch.set(_userGroupInviteIndex(member.uid)!.doc(inviteId), {

      'organizationId': orgId,

      'groupId': groupId,

      'status': GroupInviteStatus.pending.firestoreValue,

      'createdAt': Timestamp.fromDate(now),

    });

    await batch.commit();

  }



  Stream<List<GroupMembershipInvite>> watchOrgGroupInvites(String orgId) {

    return _groupInvites(orgId)

        .orderBy('createdAt', descending: true)

        .snapshots()

        .map(

          (snap) => snap.docs

              .map((doc) => GroupMembershipInvite.fromMap(doc.id, doc.data()))

              .toList(),

        );

  }



  /// Pending group invitations for the signed-in user.
  Stream<List<GroupMembershipInvite>> watchPendingInvitesForCurrentUser() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return watchPendingInvitesForUid(uid);
  }

  /// Pending group invitations for [uid].
  Stream<List<GroupMembershipInvite>> watchPendingInvitesForUid(String uid) {
    StreamSubscription<dynamic>? indexSub;
    StreamSubscription<dynamic>? orgSub;
    var disposed = false;

    Future<void> publish(StreamController<List<GroupMembershipInvite>> c) async {
      if (disposed || c.isClosed) return;
      try {
        final invites = await loadPendingInvitesForUid(uid);
        if (!disposed && !c.isClosed) c.add(invites);
      } catch (e, st) {
        debugPrint('GroupInviteService.watchPendingInvitesForUid: $e\n$st');
        if (!disposed && !c.isClosed) c.addError(e, st);
      }
    }

    late StreamController<List<GroupMembershipInvite>> controller;
    controller = StreamController<List<GroupMembershipInvite>>(
      onListen: () {
        publish(controller);
        indexSub = _userGroupInviteIndex(uid)!
            .snapshots()
            .listen((_) => publish(controller));
        orgSub = _firestore
            .collection('users')
            .doc(uid)
            .collection('orgMemberships')
            .snapshots()
            .listen((_) => publish(controller));
      },
      onCancel: () {
        disposed = true;
        indexSub?.cancel();
        orgSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Loads pending invitations from every delivery path Firestore allows.
  Future<List<GroupMembershipInvite>> loadPendingInvitesForUid(String uid) async {
    final byId = <String, GroupMembershipInvite>{};

    await _collectInvitesFromUserIndex(uid, byId);
    await _collectInvitesFromMemberOrgs(uid, byId);

    if (byId.isEmpty) {
      await _collectInvitesFromCollectionGroup(uid, byId);
    }
    if (byId.isEmpty) {
      for (final invite in await _loadPendingByEmail(uid)) {
        byId[invite.id] = invite;
      }
    }

    final invites = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (kDebugMode) {
      debugPrint(
        'GroupInviteService.loadPendingInvitesForUid($uid): '
        '${invites.length} pending invite(s)',
      );
    }

    unawaited(_syncUserInviteIndex(uid, invites));
    return invites;
  }

  Future<void> _collectInvitesFromUserIndex(
    String uid,
    Map<String, GroupMembershipInvite> byId,
  ) async {
    try {
      final snap = await _userGroupInviteIndex(uid)!.get();
      for (final invite in await _resolveInvitesFromUserIndex(snap, uid)) {
        byId[invite.id] = invite;
      }
    } catch (e, st) {
      debugPrint('GroupInviteService._collectInvitesFromUserIndex: $e\n$st');
    }
  }

  Future<void> _collectInvitesFromMemberOrgs(
    String uid,
    Map<String, GroupMembershipInvite> byId,
  ) async {
    try {
      final orgSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('orgMemberships')
          .get();

      for (final orgDoc in orgSnap.docs) {
        final orgId = orgDoc.id;
        if (orgId.isEmpty) continue;

        try {
          final inviteSnap = await _groupInvites(orgId)
              .where('inviteeUid', isEqualTo: uid)
              .where('status', isEqualTo: GroupInviteStatus.pending.firestoreValue)
              .get();
          for (final doc in inviteSnap.docs) {
            final invite = GroupMembershipInvite.fromMap(doc.id, doc.data());
            if (_isPendingInviteForUser(invite, uid)) {
              byId[invite.id] = invite;
            }
          }
        } catch (e, st) {
          debugPrint(
            'GroupInviteService._collectInvitesFromMemberOrgs($orgId): $e\n$st',
          );
        }
      }
    } catch (e, st) {
      debugPrint('GroupInviteService._collectInvitesFromMemberOrgs: $e\n$st');
    }
  }

  Future<void> _collectInvitesFromCollectionGroup(
    String uid,
    Map<String, GroupMembershipInvite> byId,
  ) async {
    try {
      final snap = await _firestore
          .collectionGroup('groupInvites')
          .where('inviteeUid', isEqualTo: uid)
          .where('status', isEqualTo: GroupInviteStatus.pending.firestoreValue)
          .get();
      for (final doc in snap.docs) {
        final invite = GroupMembershipInvite.fromMap(doc.id, doc.data());
        if (_isPendingInviteForUser(invite, uid)) {
          byId[invite.id] = invite;
        }
      }
    } catch (e, st) {
      debugPrint('GroupInviteService._collectInvitesFromCollectionGroup: $e\n$st');
    }
  }

  Future<List<GroupMembershipInvite>> _resolveInvitesFromUserIndex(
    QuerySnapshot<Map<String, dynamic>> snap,
    String uid,
  ) async {
    final invites = <GroupMembershipInvite>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final indexStatus =
          data['status'] as String? ?? GroupInviteStatus.pending.firestoreValue;
      if (indexStatus != GroupInviteStatus.pending.firestoreValue) continue;

      final orgId = data['organizationId'] as String?;
      if (orgId == null || orgId.isEmpty) continue;

      try {
        final inviteSnap = await _groupInvites(orgId).doc(doc.id).get();
        if (!inviteSnap.exists || inviteSnap.data() == null) continue;

        final invite = GroupMembershipInvite.fromMap(doc.id, inviteSnap.data()!);
        if (_isPendingInviteForUser(invite, uid)) {
          invites.add(invite);
        }
      } catch (e, st) {
        debugPrint('GroupInviteService._resolveInvitesFromUserIndex: $e\n$st');
      }
    }

    invites.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return invites;
  }

  Future<List<GroupMembershipInvite>> _loadPendingByEmail(String uid) async {
    final email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) return const [];

    final normalized = OrganizationService.normalizeEmail(email);
    try {
      final snap = await _firestore
          .collectionGroup('groupInvites')
          .where('inviteeEmail', isEqualTo: normalized)
          .where('status', isEqualTo: GroupInviteStatus.pending.firestoreValue)
          .get();
      return snap.docs
          .map((doc) => GroupMembershipInvite.fromMap(doc.id, doc.data()))
          .where((invite) => _isPendingInviteForUser(invite, uid))
          .toList();
    } catch (e, st) {
      debugPrint('GroupInviteService._loadPendingByEmail: $e\n$st');
      return const [];
    }
  }

  bool _isPendingInviteForUser(GroupMembershipInvite invite, String uid) {
    if (invite.status != GroupInviteStatus.pending) return false;
    if (invite.inviteeUid == uid) return true;

    final email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) return false;
    return OrganizationService.normalizeEmail(invite.inviteeEmail) ==
        OrganizationService.normalizeEmail(email);
  }

  bool _canRespondToInvite(GroupMembershipInvite invite, String uid) {
    return _isPendingInviteForUser(invite, uid);
  }

  Future<void> _syncUserInviteIndex(
    String uid,
    List<GroupMembershipInvite> invites,
  ) async {
    for (final invite in invites) {
      try {
        await _userGroupInviteIndex(uid)!.doc(invite.id).set(
          {
            'organizationId': invite.organizationId,
            'groupId': invite.groupId,
            'status': GroupInviteStatus.pending.firestoreValue,
            'createdAt': Timestamp.fromDate(invite.createdAt),
          },
          SetOptions(merge: true),
        );
      } catch (e, st) {
        debugPrint('GroupInviteService._syncUserInviteIndex: $e\n$st');
      }
    }
  }



  /// Backfills users/{uid}/pendingGroupInvites when groupInvites exist without index docs.

  Future<void> repairGroupInviteDelivery(GroupMembershipInvite invite) async {

    await _organizationService.ensureCanSendGroupInvite(invite.organizationId);

    if (invite.status != GroupInviteStatus.pending) return;



    await _userGroupInviteIndex(invite.inviteeUid)!.doc(invite.id).set(

      {

        'organizationId': invite.organizationId,

        'groupId': invite.groupId,

        'status': GroupInviteStatus.pending.firestoreValue,

        'createdAt': Timestamp.fromDate(invite.createdAt),

      },

      SetOptions(merge: true),

    );

  }



  Future<void> repairAllPendingGroupInviteIndexes(String orgId) async {

    final snap = await _groupInvites(orgId)

        .where('status', isEqualTo: GroupInviteStatus.pending.firestoreValue)

        .get();

    for (final doc in snap.docs) {

      final invite = GroupMembershipInvite.fromMap(doc.id, doc.data());

      await repairGroupInviteDelivery(invite);

    }

  }



  Future<void> acceptInvite(GroupMembershipInvite invite) async {

    final uid = _uid;

    if (uid == null || !_canRespondToInvite(invite, uid)) {

      throw Exception('You can only respond to your own invitations.');

    }

    if (invite.status != GroupInviteStatus.pending) {

      throw Exception('This invitation is no longer active.');

    }



    final memberRef = _firestore

        .collection('organizations')

        .doc(invite.organizationId)

        .collection('members')

        .doc(uid);



    final memberSnap = await memberRef.get();

    if (!memberSnap.exists || memberSnap.data() == null) {

      throw Exception('Organization membership not found.');

    }



    final membership = OrganizationMembership.fromMap(uid, memberSnap.data()!);

    if (membership.groupIds.contains(invite.groupId)) {

      await _finalizeInviteResponse(invite, GroupInviteStatus.accepted, uid: uid);

      await _syncGroupIndex(invite);

      await _groupScheduleService.syncSchedulesForNewMember(

        orgId: invite.organizationId,

        groupId: invite.groupId,

        memberUid: uid,

      );

      await _groupGiftService.syncGiftsForNewMember(

        orgId: invite.organizationId,

        groupId: invite.groupId,

        memberUid: uid,

      );

      return;

    }



    final indexRef = _userGroupInviteIndex(uid)!.doc(invite.id);
    final indexSnap = await indexRef.get();

    final updatedGroups = [...membership.groupIds, invite.groupId];
    final batch = _firestore.batch();

    batch.update(memberRef, {'groupIds': updatedGroups});
    batch.update(_groupInvites(invite.organizationId).doc(invite.id), {

      'status': GroupInviteStatus.accepted.firestoreValue,

      'respondedAt': FieldValue.serverTimestamp(),

    });

    if (indexSnap.exists) {

      batch.update(indexRef, {

        'status': GroupInviteStatus.accepted.firestoreValue,

      });

    }

    await batch.commit();



    await _syncGroupIndex(invite);

    await _groupScheduleService.syncSchedulesForNewMember(

      orgId: invite.organizationId,

      groupId: invite.groupId,

      memberUid: uid,

    );

    await _groupGiftService.syncGiftsForNewMember(

      orgId: invite.organizationId,

      groupId: invite.groupId,

      memberUid: uid,

    );

  }



  Future<void> _syncGroupIndex(GroupMembershipInvite invite) async {

    await _userGroupsService.upsertGroupMembershipIndex(

      ShareableGroup(

        organizationId: invite.organizationId,

        organizationName: invite.organizationName ?? '',

        groupId: invite.groupId,

        groupName: invite.groupName,

      ),

    );

  }



  Future<void> rejectInvite(GroupMembershipInvite invite) async {

    final uid = _uid;

    if (uid == null || !_canRespondToInvite(invite, uid)) {

      throw Exception('You can only respond to your own invitations.');

    }

    if (invite.status != GroupInviteStatus.pending) {

      throw Exception('This invitation is no longer active.');

    }

    await _finalizeInviteResponse(invite, GroupInviteStatus.rejected, uid: uid);

  }



  Future<void> _finalizeInviteResponse(
    GroupMembershipInvite invite,
    GroupInviteStatus status, {
    String? uid,
  }) async {
    final responderUid = uid ?? invite.inviteeUid;
    final indexRef =
        _userGroupInviteIndex(responderUid)!.doc(invite.id);

    final indexSnap = await indexRef.get();



    final batch = _firestore.batch();

    batch.update(_groupInvites(invite.organizationId).doc(invite.id), {

      'status': status.firestoreValue,

      'respondedAt': FieldValue.serverTimestamp(),

    });

    if (indexSnap.exists) {

      batch.update(indexRef, {'status': status.firestoreValue});

    }

    await batch.commit();

  }



  /// Admin removes a member from a group without consent (removal only).

  Future<void> removeMemberFromGroup({

    required String orgId,

    required String memberUid,

    required String groupId,

  }) async {

    final memberRef = _firestore

        .collection('organizations')

        .doc(orgId)

        .collection('members')

        .doc(memberUid);

    final snap = await memberRef.get();

    if (!snap.exists || snap.data() == null) return;



    final membership = OrganizationMembership.fromMap(memberUid, snap.data()!);

    final updated = membership.groupIds.where((id) => id != groupId).toList();

    await memberRef.update({'groupIds': updated});

    await _firestore

        .collection('users')

        .doc(memberUid)

        .collection('groupMemberships')

        .doc(groupId)

        .delete();

    await _groupScheduleService.removePracticesForMember(

      orgId: orgId,

      groupId: groupId,

      memberUid: memberUid,

    );

    await _groupGiftService.removeGiftsForMember(

      orgId: orgId,

      groupId: groupId,

      memberUid: memberUid,

    );

  }

}


