import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/admin_config.dart';
import '../models/admin_role.dart';
import '../models/ministry_group.dart';
import '../models/organization.dart';
import '../models/organization_invite.dart';
import '../models/organization_membership.dart';
import 'group_gift_service.dart';
import 'group_schedule_service.dart';

/// Firestore access for organizations, groups, memberships, and invites.
///
/// Organizational data only — never reads personal spiritual content
/// (`users/{uid}/sessionHistory`, reflections, etc.).
class OrganizationService {
  OrganizationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Uuid _uuid;
  final GroupGiftService _groupGiftService = GroupGiftService();
  final GroupScheduleService _groupScheduleService = GroupScheduleService();

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _organizations =>
      _firestore.collection('organizations');

  CollectionReference<Map<String, dynamic>>? _userMembershipIndex(String uid) {
    if (uid.isEmpty) return null;
    return _firestore.collection('users').doc(uid).collection('orgMemberships');
  }

  CollectionReference<Map<String, dynamic>>? _userGroupMembershipIndex(
    String uid,
  ) {
    if (uid.isEmpty) return null;
    return _firestore.collection('users').doc(uid).collection('groupMemberships');
  }

  static String normalizeEmail(String email) =>
      email.trim().toLowerCase();

  /// Union of group ids, preserving first-seen order.
  static List<String> mergeGroupIds(
    Iterable<String> existing,
    Iterable<String> incoming,
  ) {
    final seen = <String>{};
    final merged = <String>[];
    for (final id in [...existing, ...incoming]) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      merged.add(trimmed);
    }
    return merged;
  }

  /// One stable Firestore id per org + email so re-invites update instead of failing.
  static String stableInviteId(String orgId, String normalizedEmail) {
    final safeEmail = normalizedEmail
        .replaceAll('@', '_at_')
        .replaceAll('.', '_dot_')
        .replaceAll('+', '_plus_');
    return 'inv_${orgId}_$safeEmail';
  }

  // --- Organizations ---

  Stream<List<Organization>> watchOrganizationsForCurrentUser() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    return _userMembershipIndex(uid)!
        .snapshots()
        .asyncMap((snap) async {
      final orgs = <Organization>[];
      for (final doc in snap.docs) {
        final orgId = doc.id;
        final orgSnap = await _organizations.doc(orgId).get();
        if (orgSnap.exists && orgSnap.data() != null) {
          orgs.add(Organization.fromMap(orgId, orgSnap.data()!));
        }
      }
      orgs.sort((a, b) => a.name.compareTo(b.name));
      return orgs;
    });
  }

  /// Overall Admin — all organizations on the platform.
  Stream<List<Organization>> watchAllOrganizations() {
    return _organizations.orderBy('name').snapshots().map(
          (snap) => snap.docs
              .map((doc) => Organization.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<Organization?> getOrganization(String orgId) async {
    final snap = await _organizations.doc(orgId).get();
    if (!snap.exists || snap.data() == null) return null;
    return Organization.fromMap(snap.id, snap.data()!);
  }

  Stream<Organization?> watchOrganization(String orgId) {
    if (orgId.isEmpty) return Stream.value(null);
    return _organizations.doc(orgId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return Organization.fromMap(snap.id, snap.data()!);
    });
  }

  Future<String> createOrganization({
    required String name,
    required OrganizationType type,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Sign in to create an organization.');
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Organization name is required.');
    }

    final now = DateTime.now();
    final orgRef = _organizations.doc();
    final org = Organization(
      id: orgRef.id,
      name: trimmed,
      type: type,
      createdAt: now,
      createdByUid: uid,
    );

    final membership = OrganizationMembership(
      uid: uid,
      organizationId: orgRef.id,
      role: AdminRole.orgAdmin,
      joinedAt: now,
      email: _auth.currentUser?.email,
      invitedByUid: uid,
    );

    final batch = _firestore.batch();
    batch.set(orgRef, org.toMap());
    batch.set(
      orgRef.collection('members').doc(uid),
      membership.toMap(),
    );
    batch.set(
      _userMembershipIndex(uid)!.doc(orgRef.id),
      {
        'organizationId': orgRef.id,
        'role': AdminRole.orgAdmin.firestoreValue,
        'joinedAt': Timestamp.fromDate(now),
      },
    );
    await batch.commit();
    return orgRef.id;
  }

  Future<void> updateOrganization({
    required String orgId,
    required String name,
    OrganizationType? type,
    String? logoUrl,
    bool clearLogo = false,
  }) async {
    await _requireOrgAdmin(orgId);

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Organization name is required.');
    }

    final updates = <String, dynamic>{
      'name': trimmed,
      if (type != null) 'type': type.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (clearLogo) {
      updates['logoUrl'] = FieldValue.delete();
    } else if (logoUrl != null) {
      final logo = logoUrl.trim();
      updates['logoUrl'] =
          logo.isEmpty ? FieldValue.delete() : logo;
    }
    await _organizations.doc(orgId).update(updates);
  }

  // --- Membership ---

  Stream<OrganizationMembership?> watchMembership({
    required String orgId,
    String? uid,
  }) {
    final memberUid = uid ?? _uid;
    if (memberUid == null) return Stream.value(null);

    return _organizations
        .doc(orgId)
        .collection('members')
        .doc(memberUid)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return OrganizationMembership.fromMap(snap.id, snap.data()!);
    });
  }

  Stream<List<OrganizationMembership>> watchMembers(String orgId) {
    return _organizations
        .doc(orgId)
        .collection('members')
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => OrganizationMembership.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> updateMemberRole({
    required String orgId,
    required String memberUid,
    required AdminRole role,
  }) async {
    await _requireOrgAdmin(orgId);

    await _organizations.doc(orgId).collection('members').doc(memberUid).update({
      'role': role.firestoreValue,
    });
    await _userMembershipIndex(memberUid)?.doc(orgId).update({
      'role': role.firestoreValue,
    });
  }

  Future<void> updateMemberGroups({
    required String orgId,
    required String memberUid,
    required List<String> groupIds,
  }) async {
    await _requireCanManageGroups(orgId);

    final memberRef =
        _organizations.doc(orgId).collection('members').doc(memberUid);
    final memberSnap = await memberRef.get();
    final previousGroupIds = memberSnap.exists && memberSnap.data() != null
        ? OrganizationMembership.fromMap(memberUid, memberSnap.data()!)
            .groupIds
        : const <String>[];

    await memberRef.update({
      'groupIds': groupIds,
    });

    final removed =
        previousGroupIds.where((id) => !groupIds.contains(id)).toList();
    final added =
        groupIds.where((id) => !previousGroupIds.contains(id)).toList();

    final groupIndex = _userGroupMembershipIndex(memberUid);
    if (groupIndex != null) {
      for (final groupId in removed) {
        await groupIndex.doc(groupId).delete();
      }
    }
    if (added.isNotEmpty) {
      await _syncMemberGroupIndexes(
        uid: memberUid,
        orgId: orgId,
        groupIds: added,
      );
      for (final groupId in added) {
        await _syncGroupContentForMember(
          orgId: orgId,
          groupId: groupId,
          memberUid: memberUid,
        );
      }
    }
    for (final groupId in removed) {
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

  Future<void> removeMember({
    required String orgId,
    required String memberUid,
  }) async {
    await _requireOrgAdmin(orgId);
    if (memberUid == _uid) {
      throw Exception('Use leave organization instead of removing yourself.');
    }

    final batch = _firestore.batch();
    batch.delete(_organizations.doc(orgId).collection('members').doc(memberUid));
    batch.delete(_userMembershipIndex(memberUid)!.doc(orgId));
    await batch.commit();
  }

  // --- Groups ---

  Stream<List<MinistryGroup>> watchGroups(String orgId) {
    return _organizations
        .doc(orgId)
        .collection('groups')
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => MinistryGroup.fromMap(
                  doc.id,
                  doc.data(),
                  organizationId: orgId,
                ),
              )
              .toList(),
        );
  }

    Future<String> createGroup({
    required String orgId,
    required String name,
    String? ageBand,
    String? description,
    String? logoUrl,
  }) async {
    await _ensureCreatorMembership(orgId);
    await _requireCanManageGroups(orgId);

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Group name is required.');
    }

    final ref = _organizations.doc(orgId).collection('groups').doc();
    final group = MinistryGroup(
      id: ref.id,
      organizationId: orgId,
      name: trimmed,
      createdAt: DateTime.now(),
      ageBand: ageBand?.trim(),
      description: description?.trim(),
      logoUrl: logoUrl?.trim(),
    );
    await ref.set(group.toMap());

    final uid = _uid;
    if (uid != null) {
      await joinGroupAsCurrentMember(orgId: orgId, groupId: ref.id);
    }

    return ref.id;
  }

  /// Adds the signed-in org member to a group (for sharing and group practices).
  Future<void> joinGroupAsCurrentMember({
    required String orgId,
    required String groupId,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Sign in to join a group.');
    }

    final memberRef =
        _organizations.doc(orgId).collection('members').doc(uid);
    final memberSnap = await memberRef.get();
    if (!memberSnap.exists || memberSnap.data() == null) {
      throw Exception('Organization membership not found.');
    }

    final membership =
        OrganizationMembership.fromMap(uid, memberSnap.data()!);
    if (membership.groupIds.contains(groupId)) {
      await _syncMemberGroupIndexes(
        uid: uid,
        orgId: orgId,
        groupIds: [groupId],
      );
      await _syncGroupContentForMember(
        orgId: orgId,
        groupId: groupId,
        memberUid: uid,
      );
      return;
    }

    await memberRef.update({
      'groupIds': FieldValue.arrayUnion([groupId]),
    });
    await _syncMemberGroupIndexes(
      uid: uid,
      orgId: orgId,
      groupIds: [groupId],
    );
    await _syncGroupContentForMember(
      orgId: orgId,
      groupId: groupId,
      memberUid: uid,
    );
  }

    Future<void> updateGroup({
    required String orgId,
    required String groupId,
    required String name,
    String? ageBand,
    String? description,
    String? logoUrl,
  }) async {
    await _ensureCreatorMembership(orgId);
    await _requireCanManageGroups(orgId);

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Group name is required.');
    }

    await _organizations.doc(orgId).collection('groups').doc(groupId).update({
      'name': trimmed,
      'ageBand': ageBand?.trim(),
      'description': description?.trim(),
      if (logoUrl == null || logoUrl.trim().isEmpty)
        'logoUrl': FieldValue.delete()
      else
        'logoUrl': logoUrl.trim(),
    });
  }

  Future<void> deleteGroup({
    required String orgId,
    required String groupId,
  }) async {
    await _ensureCreatorMembership(orgId);
    await _requireCanManageGroups(orgId);
    await _organizations.doc(orgId).collection('groups').doc(groupId).delete();
  }

  // --- Invites ---

  CollectionReference<Map<String, dynamic>> _pendingJoinByEmail(String email) {
    return _firestore
        .collection('pendingOrgJoinsByEmail')
        .doc(normalizeEmail(email))
        .collection('orgs');
  }

  CollectionReference<Map<String, dynamic>> _emailInviteIndex(String email) {
    return _firestore
        .collection('emailInvites')
        .doc(normalizeEmail(email))
        .collection('items');
  }

  Stream<List<OrganizationInvite>> watchPendingInvitesForCurrentUser() {
    final email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) return Stream.value(const []);
    return watchPendingOrgInvitesForEmail(email);
  }

  /// Real-time pending organization invitations for [email].
  Stream<List<OrganizationInvite>> watchPendingOrgInvitesForEmail(String email) {
    final normalized = normalizeEmail(email);
    StreamSubscription<dynamic>? emailSub;
    StreamSubscription<dynamic>? joinSub;
    var disposed = false;

    Future<void> publish(StreamController<List<OrganizationInvite>> c) async {
      if (disposed || c.isClosed) return;
      try {
        final invites = await loadPendingOrgInvitesForEmail(email);
        if (!disposed && !c.isClosed) c.add(invites);
      } catch (e, st) {
        debugPrint('OrganizationService.watchPendingOrgInvitesForEmail: $e\n$st');
        // Keep the last successful list so Accept/Decline stay tappable.
      }
    }

    late StreamController<List<OrganizationInvite>> controller;
    controller = StreamController<List<OrganizationInvite>>(
      onListen: () {
        publish(controller);
        emailSub = _emailInviteIndex(email).snapshots().listen(
              (_) => publish(controller),
              onError: (Object e, StackTrace st) {
                debugPrint(
                  'OrganizationService.watchPendingOrgInvitesForEmail email: $e\n$st',
                );
              },
            );
        joinSub = _pendingJoinByEmail(normalized).snapshots().listen(
              (_) => publish(controller),
              onError: (Object e, StackTrace st) {
                debugPrint(
                  'OrganizationService.watchPendingOrgInvitesForEmail join: $e\n$st',
                );
              },
            );
      },
      onCancel: () {
        disposed = true;
        emailSub?.cancel();
        joinSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Loads pending organization invitations from every delivery path.
  Future<List<OrganizationInvite>> loadPendingOrgInvitesForEmail(
    String email,
  ) async {
    final normalized = normalizeEmail(email);
    if (normalized.isEmpty) return const [];

    final byId = <String, OrganizationInvite>{};
    await _collectOrgInvitesFromEmailIndex(normalized, byId);
    await _collectOrgInvitesFromJoinIndex(normalized, byId);
    if (byId.isEmpty) {
      await _collectOrgInvitesFromCollectionGroup(normalized, byId);
    }

    final invites = byId.values
        .where((invite) => invite.status == InviteStatus.pending)
        .toList();
    await _enrichOrgInviteNames(invites);

    invites.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (kDebugMode) {
      debugPrint(
        'OrganizationService.loadPendingOrgInvitesForEmail($normalized): '
        '${invites.length} pending invite(s)',
      );
    }

    return invites;
  }

  Future<void> _collectOrgInvitesFromEmailIndex(
    String normalizedEmail,
    Map<String, OrganizationInvite> byId,
  ) async {
    try {
      final snap = await _emailInviteIndex(normalizedEmail)
          .where('status', isEqualTo: InviteStatus.pending.firestoreValue)
          .get();
      for (final doc in snap.docs) {
        final invite = OrganizationInvite.fromMap(doc.id, doc.data());
        if (invite.status == InviteStatus.pending &&
            normalizeEmail(invite.email) == normalizedEmail) {
          byId[invite.id] = invite;
        }
      }
    } catch (e, st) {
      debugPrint('OrganizationService._collectOrgInvitesFromEmailIndex: $e\n$st');
    }
  }

  Future<void> _collectOrgInvitesFromJoinIndex(
    String normalizedEmail,
    Map<String, OrganizationInvite> byId,
  ) async {
    try {
      final pendingJoins = await _pendingJoinByEmail(normalizedEmail).get();
      for (final joinDoc in pendingJoins.docs) {
        final orgId = joinDoc.id;
        final data = joinDoc.data();
        if ((data['status'] as String? ?? '') !=
            InviteStatus.pending.firestoreValue) {
          continue;
        }
        final inviteId = stableInviteId(orgId, normalizedEmail);
        final invite = OrganizationInvite.fromMap(inviteId, {
          ...data,
          'organizationId': orgId,
          'email': normalizedEmail,
          'status': InviteStatus.pending.firestoreValue,
        });
        if (invite.status == InviteStatus.pending) {
          byId[invite.id] = invite;
        }
      }
    } catch (e, st) {
      debugPrint('OrganizationService._collectOrgInvitesFromJoinIndex: $e\n$st');
    }
  }

  Future<void> _collectOrgInvitesFromCollectionGroup(
    String normalizedEmail,
    Map<String, OrganizationInvite> byId,
  ) async {
    try {
      final snap = await _firestore
          .collectionGroup('invites')
          .where('email', isEqualTo: normalizedEmail)
          .where('status', isEqualTo: InviteStatus.pending.firestoreValue)
          .get();
      for (final doc in snap.docs) {
        final invite = OrganizationInvite.fromMap(doc.id, doc.data());
        if (invite.status == InviteStatus.pending &&
            normalizeEmail(invite.email) == normalizedEmail) {
          byId[invite.id] = invite;
        }
      }
    } catch (e, st) {
      debugPrint('OrganizationService._collectOrgInvitesFromCollectionGroup: $e\n$st');
    }
  }

  Future<void> _enrichOrgInviteNames(List<OrganizationInvite> invites) async {
    for (var i = 0; i < invites.length; i++) {
      final invite = invites[i];
      final existing = invite.organizationName?.trim();
      if (existing != null && existing.isNotEmpty) continue;

      try {
        final orgSnap = await _organizations.doc(invite.organizationId).get();
        final name = orgSnap.data()?['name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          invites[i] = OrganizationInvite(
            id: invite.id,
            organizationId: invite.organizationId,
            email: invite.email,
            role: invite.role,
            status: invite.status,
            createdAt: invite.createdAt,
            groupIds: invite.groupIds,
            invitedByUid: invite.invitedByUid,
            organizationName: name.trim(),
          );
        }
      } catch (e, st) {
        debugPrint('OrganizationService._enrichOrgInviteNames: $e\n$st');
      }
    }
  }

  /// Backfills email delivery docs when an org invite exists but indexes are missing.
  Future<void> repairOrgInviteDelivery({
    required String orgId,
    required OrganizationInvite invite,
  }) async {
    await _ensureInviteSendPermission(orgId, invite.role);
    if (invite.status != InviteStatus.pending) return;

    final normalized = normalizeEmail(invite.email);
    final stableId = stableInviteId(orgId, normalized);
    final repaired = OrganizationInvite(
      id: stableId,
      organizationId: invite.organizationId,
      email: normalized,
      role: invite.role,
      status: invite.status,
      createdAt: invite.createdAt,
      groupIds: invite.groupIds,
      invitedByUid: invite.invitedByUid,
      organizationName: invite.organizationName,
    );

    final batch = _firestore.batch();
    batch.set(
      _organizations.doc(orgId).collection('invites').doc(stableId),
      repaired.toMap(),
      SetOptions(merge: true),
    );
    batch.set(
      _emailInviteIndex(normalized).doc(stableId),
      repaired.toMap(),
      SetOptions(merge: true),
    );
    batch.set(
      _pendingJoinByEmail(normalized).doc(orgId),
      repaired.toMap(),
      SetOptions(merge: true),
    );
    if (invite.id != stableId) {
      batch.set(
        _organizations.doc(orgId).collection('invites').doc(invite.id),
        {'status': InviteStatus.revoked.firestoreValue},
        SetOptions(merge: true),
      );
      batch.set(
        _emailInviteIndex(normalized).doc(invite.id),
        {'status': InviteStatus.revoked.firestoreValue},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> repairAllPendingOrgInviteDelivery(String orgId) async {
    final snap = await _organizations
        .doc(orgId)
        .collection('invites')
        .where('status', isEqualTo: InviteStatus.pending.firestoreValue)
        .get();
    for (final doc in snap.docs) {
      final invite = OrganizationInvite.fromMap(doc.id, doc.data());
      await repairOrgInviteDelivery(orgId: orgId, invite: invite);
    }
  }

  Stream<List<OrganizationInvite>> watchInvitesForOrganization(String orgId) {
    return _organizations
        .doc(orgId)
        .collection('invites')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => OrganizationInvite.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> createInvite({
    required String orgId,
    required String email,
    AdminRole role = AdminRole.member,
    List<String> groupIds = const [],
  }) async {
    await _ensureCreatorMembership(orgId);
    await _ensureInviteSendPermission(orgId, role);

    final normalized = normalizeEmail(email);
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw Exception('Enter a valid email address.');
    }

    final org = await getOrganization(orgId);
    if (org == null) throw Exception('Organization not found.');

    final uid = _uid!;
    final now = DateTime.now();
    final inviteId = stableInviteId(orgId, normalized);

    final invite = OrganizationInvite(
      id: inviteId,
      organizationId: orgId,
      email: normalized,
      role: role,
      status: InviteStatus.pending,
      createdAt: now,
      groupIds: groupIds,
      invitedByUid: uid,
      organizationName: org.name,
    );

    final payload = invite.toMap();

    final batch = _firestore.batch();
    batch.set(
      _organizations.doc(orgId).collection('invites').doc(inviteId),
      payload,
      SetOptions(merge: true),
    );
    batch.set(
      _emailInviteIndex(normalized).doc(inviteId),
      payload,
      SetOptions(merge: true),
    );
    batch.set(
      _pendingJoinByEmail(normalized).doc(orgId),
      payload,
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> _ensureInviteSendPermission(String orgId, AdminRole role) async {
    if (role == AdminRole.orgAdmin) {
      if (!await _canManageOrganizationForOrg(orgId)) {
        throw Exception(
          'Only organization administrators can invite other organization '
          'administrators. Group leaders may invite members or group leaders only.',
        );
      }
      return;
    }

    if (!await _canManageGroupsForOrg(orgId)) {
      throw Exception(
        'Your account cannot send organization invitations. Confirm with your '
        'organization administrator that you have permission to invite members.',
      );
    }
  }

  Future<void> acceptInvite(OrganizationInvite invite) async {
    final uid = _uid;
    final email = _auth.currentUser?.email;
    if (uid == null) {
      throw Exception('Sign in to accept an invitation.');
    }
    if (email == null ||
        normalizeEmail(email) != normalizeEmail(invite.email)) {
      throw Exception(
        'This invitation was sent to ${invite.email}. '
        'Sign in with that exact email address to accept.',
      );
    }
    if (invite.status != InviteStatus.pending) {
      throw Exception('This invitation is no longer active.');
    }

    final orgId = invite.organizationId;
    final normalized = normalizeEmail(email);
    final memberRef =
        _organizations.doc(orgId).collection('members').doc(uid);
    final memberSnap = await memberRef.get();
    final joinRef = _pendingJoinByEmail(normalized).doc(orgId);
    final joinSnap = await joinRef.get();
    final emailIndexRef = _emailInviteIndex(normalized).doc(invite.id);
    final emailIndexSnap = await emailIndexRef.get();
    final orgInviteRef =
        _organizations.doc(orgId).collection('invites').doc(invite.id);

    if (!memberSnap.exists && !joinSnap.exists) {
      throw Exception(
        'This invitation is not fully delivered yet. Ask your organization '
        'administrator to open Admin → Organization → Org invites and tap '
        '"Refresh delivery" for pending invitations.',
      );
    }

    final now = DateTime.now();
    final acceptedFields = {
      'status': InviteStatus.accepted.firestoreValue,
      'acceptedAt': FieldValue.serverTimestamp(),
      'acceptedByUid': uid,
    };

    final existing = memberSnap.exists && memberSnap.data() != null
        ? OrganizationMembership.fromMap(uid, memberSnap.data()!)
        : null;
    final mergedGroupIds = mergeGroupIds(
      existing?.groupIds ?? const [],
      invite.groupIds,
    );

    final indexRef = _userMembershipIndex(uid)?.doc(orgId);
    final indexSnap = indexRef == null ? null : await indexRef.get();

    final batch = _firestore.batch();
    if (existing == null) {
      batch.set(
        memberRef,
        OrganizationMembership(
          uid: uid,
          organizationId: orgId,
          role: invite.role,
          joinedAt: now,
          email: normalized,
          groupIds: mergedGroupIds,
          invitedByUid: invite.invitedByUid,
        ).toMap(),
      );
    } else if (!_sameGroupIds(existing.groupIds, mergedGroupIds)) {
      batch.update(memberRef, {'groupIds': mergedGroupIds});
    }

    if (indexRef != null) {
      final roleValue =
          existing?.role.firestoreValue ?? invite.role.firestoreValue;
      final canCreateIndex = joinSnap.exists ||
          roleValue == AdminRole.member.firestoreValue;
      if (indexSnap != null && indexSnap.exists) {
        batch.set(
          indexRef,
          {
            'organizationId': orgId,
            'role': roleValue,
            'joinedAt': existing != null
                ? Timestamp.fromDate(existing.joinedAt)
                : Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      } else if (canCreateIndex) {
        batch.set(
          indexRef,
          {
            'organizationId': orgId,
            'role': roleValue,
            'joinedAt': Timestamp.fromDate(now),
          },
        );
      }
    }

    batch.update(orgInviteRef, acceptedFields);
    if (emailIndexSnap.exists) {
      batch.update(emailIndexRef, acceptedFields);
    }
    if (joinSnap.exists) {
      batch.delete(joinRef);
    }
    await batch.commit();

    final groupsToSync = existing == null
        ? mergedGroupIds
        : invite.groupIds
            .where((id) => !existing.groupIds.contains(id))
            .toList();
    if (groupsToSync.isEmpty) return;
    try {
      await _syncMemberGroupIndexes(
        uid: uid,
        orgId: orgId,
        groupIds: groupsToSync,
      );
      for (final groupId in groupsToSync) {
        await _syncGroupContentForMember(
          orgId: orgId,
          groupId: groupId,
          memberUid: uid,
        );
      }
    } catch (e, st) {
      debugPrint('OrganizationService.acceptInvite group sync: $e\n$st');
    }
  }

  static bool _sameGroupIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    return a.toSet().containsAll(b);
  }

  /// Declines a pending organization invitation sent to the signed-in user's email.
  Future<void> declineInvite(OrganizationInvite invite) async {
    final email = _auth.currentUser?.email;
    if (email == null ||
        normalizeEmail(email) != normalizeEmail(invite.email)) {
      throw Exception(
        'This invitation was sent to ${invite.email}. '
        'Sign in with that exact email address to respond.',
      );
    }
    if (invite.status != InviteStatus.pending) {
      throw Exception('This invitation is no longer active.');
    }

    final normalized = normalizeEmail(invite.email);
    final orgId = invite.organizationId;
    final declinedFields = {
      'status': InviteStatus.revoked.firestoreValue,
    };

    final orgInviteRef =
        _organizations.doc(orgId).collection('invites').doc(invite.id);
    final emailIndexRef = _emailInviteIndex(normalized).doc(invite.id);
    final joinRef = _pendingJoinByEmail(normalized).doc(orgId);

    final emailIndexSnap = await emailIndexRef.get();
    final joinSnap = await joinRef.get();

    final batch = _firestore.batch();
    batch.update(orgInviteRef, declinedFields);
    if (emailIndexSnap.exists) {
      batch.update(emailIndexRef, declinedFields);
    }
    if (joinSnap.exists) {
      batch.delete(joinRef);
    }
    await batch.commit();
  }

  Future<void> _syncMemberGroupIndexes({
    required String uid,
    required String orgId,
    required List<String> groupIds,
  }) async {
    if (groupIds.isEmpty) return;

    final groupIndex = _userGroupMembershipIndex(uid);
    if (groupIndex == null) return;

    final orgSnap = await _organizations.doc(orgId).get();
    final orgName = orgSnap.data()?['name'] as String? ?? '';

    for (final groupId in groupIds) {
      final groupSnap =
          await _organizations.doc(orgId).collection('groups').doc(groupId).get();
      if (!groupSnap.exists || groupSnap.data() == null) continue;

      final groupName = groupSnap.data()?['name'] as String? ?? '';
      await groupIndex.doc(groupId).set(
        {
          'organizationId': orgId,
          'groupId': groupId,
          'groupName': groupName,
          'organizationName': orgName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<void> _syncGroupContentForMember({
    required String orgId,
    required String groupId,
    required String memberUid,
  }) async {
    await _groupScheduleService.syncSchedulesForNewMember(
      orgId: orgId,
      groupId: groupId,
      memberUid: memberUid,
    );
    await _groupGiftService.syncGiftsForNewMember(
      orgId: orgId,
      groupId: groupId,
      memberUid: memberUid,
    );
  }

  /// All ministry groups across organizations (Super Admin oversight only).
  Future<List<({Organization org, MinistryGroup group})>> loadAllPlatformGroups() async {
    final orgSnap = await _organizations.orderBy('name').get();
    final entries = <({Organization org, MinistryGroup group})>[];

    for (final orgDoc in orgSnap.docs) {
      final org = Organization.fromMap(orgDoc.id, orgDoc.data());
      final groupsSnap = await orgDoc.reference
          .collection('groups')
          .orderBy('name')
          .get();
      for (final groupDoc in groupsSnap.docs) {
        entries.add((
          org: org,
          group: MinistryGroup.fromMap(
            groupDoc.id,
            groupDoc.data(),
            organizationId: orgDoc.id,
          ),
        ));
      }
    }

    return entries;
  }

  Future<void> revokeInvite({
    required String orgId,
    required OrganizationInvite invite,
  }) async {
    await _requireOrgAdmin(orgId);

    final batch = _firestore.batch();
    batch.update(
      _organizations.doc(orgId).collection('invites').doc(invite.id),
      {'status': InviteStatus.revoked.firestoreValue},
    );
    batch.update(
      _emailInviteIndex(invite.email).doc(invite.id),
      {'status': InviteStatus.revoked.firestoreValue},
    );
    batch.delete(_pendingJoinByEmail(invite.email).doc(orgId));
    await batch.commit();
  }

  // --- Anonymized insights records (read-only for admins) ---

  Future<List<Map<String, dynamic>>> loadInsightsRecords({
    required String orgId,
    DateTime? since,
  }) async {
    await _requireCanViewInsights(orgId);

    Query<Map<String, dynamic>> query = _firestore
        .collection('insightsRecords')
        .where('organizationId', isEqualTo: orgId);

    if (since != null) {
      query = query.where(
        'recordedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(since),
      );
    }

    final snap = await query.get();
    return snap.docs.map((doc) => doc.data()).toList();
  }

  // --- Authorization helpers ---

  Future<OrganizationMembership?> _getMembership(String orgId) async {
    final uid = _uid;
    if (uid == null) return null;
    final snap =
        await _organizations.doc(orgId).collection('members').doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return OrganizationMembership.fromMap(snap.id, snap.data()!);
  }

  Future<void> _ensureCreatorMembership(String orgId) async {
    final uid = _uid;
    if (uid == null) return;

    final existing = await _getMembership(orgId);
    if (existing != null) return;

    final org = await getOrganization(orgId);
    if (org == null || org.createdByUid != uid) return;

    final now = DateTime.now();
    final membership = OrganizationMembership(
      uid: uid,
      organizationId: orgId,
      role: AdminRole.orgAdmin,
      joinedAt: now,
      email: _auth.currentUser?.email,
      invitedByUid: uid,
    );

    final batch = _firestore.batch();
    batch.set(
      _organizations.doc(orgId).collection('members').doc(uid),
      membership.toMap(),
    );
    batch.set(
      _userMembershipIndex(uid)!.doc(orgId),
      {
        'organizationId': orgId,
        'role': AdminRole.orgAdmin.firestoreValue,
        'joinedAt': Timestamp.fromDate(now),
      },
    );
    await batch.commit();
  }

  Future<bool> _canManageGroupsForOrg(String orgId) async {
    final uid = _uid;
    if (uid == null) return false;

    if (AdminConfig.isFoundationAdmin(_auth.currentUser?.email)) return true;

    final platformSnap = await _firestore.collection('platformAdmins').doc(uid).get();
    if (platformSnap.exists) return true;

    final membership = await _getMembership(orgId);
    if (membership?.role.canManageGroups == true) return true;

    final org = await getOrganization(orgId);
    return org != null && org.createdByUid == uid;
  }

  Future<void> _requireCanManageGroups(String orgId) async {
    if (await _canManageGroupsForOrg(orgId)) return;
    throw Exception('Missing sufficient permissions.');
  }

  /// Ensures the signed-in user may send organization email invitations.
  Future<void> ensureCanSendOrgInvite(String orgId) async {
    await _ensureCreatorMembership(orgId);
    if (await _canManageOrganizationForOrg(orgId)) return;

    throw Exception(
      'Your account cannot send organization invitations. Confirm you are '
      'listed as an organization administrator under Members.',
    );
  }

  Future<bool> _canManageOrganizationForOrg(String orgId) async {
    final uid = _uid;
    if (uid == null) return false;

    if (AdminConfig.isFoundationAdmin(_auth.currentUser?.email)) return true;

    final platformSnap =
        await _firestore.collection('platformAdmins').doc(uid).get();
    if (platformSnap.exists) return true;

    final membership = await _getMembership(orgId);
    if (membership?.role.canManageOrganization == true) return true;

    final org = await getOrganization(orgId);
    return org != null && org.createdByUid == uid;
  }

  /// Ensures the signed-in user has a Firestore membership record before
  /// sending group invitations (rules check organizations/.../members).
  Future<void> ensureCanSendGroupInvite(String orgId) async {
    await _ensureCreatorMembership(orgId);
    if (await _canManageGroupsForOrg(orgId)) return;

    throw Exception(
      'Your account cannot send group invitations for this organization. '
      'Confirm you are listed as an organization administrator or group leader '
      'under Members, then try again.',
    );
  }

  Future<void> _requireOrgAdmin(String orgId) async {
    final membership = await _getMembership(orgId);
    if (membership?.role.canManageOrganization == true) return;

    final org = await getOrganization(orgId);
    final uid = _uid;
    if (org != null && uid != null && org.createdByUid == uid) return;

    throw Exception('Organization administrator access required.');
  }

  Future<void> _requireCanViewInsights(String orgId) async {
    final membership = await _getMembership(orgId);
    if (membership?.role.canViewPastoralInsights != true) {
      throw Exception('Permission to view Pastoral Insights is required.');
    }
  }
}
