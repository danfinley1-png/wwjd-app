import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../admin/config/admin_config.dart';
import '../../admin/models/ministry_group.dart';
import '../../admin/models/organization_membership.dart';
import '../models/shareable_group.dart';

/// Loads ministry groups the signed-in user may share into.
///
/// Regular users: accepted group membership only.
/// Super Admin: all platform groups (User mode oversight).
class UserGroupsService {
  UserGroupsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>? _groupMembershipIndex(String uid) =>
      _firestore.collection('users').doc(uid).collection('groupMemberships');

  /// Groups the signed-in user belongs to (profile view — never all-platform scope).
  Stream<List<ShareableGroup>> watchProfileGroupMemberships() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _watchMemberShareableGroups(uid);
  }

  /// Real-time list of groups available for sharing in User mode.
  Stream<List<ShareableGroup>> watchShareableGroups() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const []);

    return _watchIsSuperAdmin().asyncExpand((isSuperAdmin) {
      if (isSuperAdmin) {
        return _watchAllPlatformShareableGroups();
      }
      return _watchMemberShareableGroups(user.uid);
    });
  }

  Stream<bool> _watchIsSuperAdmin() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);
    if (AdminConfig.isFoundationAdmin(user.email)) {
      return Stream.value(true);
    }
    return _firestore
        .collection('platformAdmins')
        .doc(user.uid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  Stream<List<ShareableGroup>> _watchAllPlatformShareableGroups() {
    return _firestore
        .collection('organizations')
        .orderBy('name')
        .snapshots()
        .asyncMap((_) => _loadAllPlatformShareableGroups());
  }

  Stream<List<ShareableGroup>> _watchMemberShareableGroups(String uid) {
    return _groupMembershipIndex(uid)!.snapshots().asyncMap((snap) async {
      final indexed = snap.docs
          .map((doc) => ShareableGroup.fromIndexMap(doc.id, doc.data()))
          .where((g) => g.groupName.isNotEmpty)
          .toList()
        ..sort((a, b) => a.displayLabel.compareTo(b.displayLabel));

      if (indexed.isNotEmpty) return indexed;

      final fromMembership = await _loadShareableGroupsFromMemberships(uid);
      if (fromMembership.isNotEmpty) {
        await _upsertShareableGroupIndexes(fromMembership);
      }
      return fromMembership;
    });
  }

  /// Backfills `users/{uid}/groupMemberships` from membership or platform scope.
  Future<void> repairShareableGroupsIndex() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final groups = await _isSuperAdminNow()
        ? await _loadAllPlatformShareableGroups()
        : await _loadShareableGroupsFromMemberships(uid);
    await _upsertShareableGroupIndexes(groups);
  }

  Future<bool> _isSuperAdminNow() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (AdminConfig.isFoundationAdmin(user.email)) return true;
    final snap = await _firestore.collection('platformAdmins').doc(user.uid).get();
    return snap.exists;
  }

  Future<List<ShareableGroup>> _loadAllPlatformShareableGroups() async {
    final orgSnap = await _firestore.collection('organizations').orderBy('name').get();
    final groups = <ShareableGroup>[];

    for (final orgDoc in orgSnap.docs) {
      final orgName = orgDoc.data()['name'] as String? ?? '';
      final groupsSnap = await orgDoc.reference.collection('groups').orderBy('name').get();
      for (final groupDoc in groupsSnap.docs) {
        final group = MinistryGroup.fromMap(
          groupDoc.id,
          groupDoc.data(),
          organizationId: orgDoc.id,
        );
        groups.add(
          ShareableGroup(
            organizationId: orgDoc.id,
            organizationName: orgName,
            groupId: group.id,
            groupName: group.name,
          ),
        );
      }
    }

    groups.sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
    return groups;
  }

  Future<void> _upsertShareableGroupIndexes(List<ShareableGroup> groups) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || groups.isEmpty) return;

    final index = _groupMembershipIndex(uid)!;
    for (final group in groups) {
      await index.doc(group.groupId).set(
            {
              ...group.toIndexMap(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
    }
  }

  Future<List<ShareableGroup>> _loadShareableGroupsFromMemberships(String uid) async {
    final orgIndex = await _firestore
        .collection('users')
        .doc(uid)
        .collection('orgMemberships')
        .get();
    final groups = <ShareableGroup>[];

    for (final orgDoc in orgIndex.docs) {
      final orgId = orgDoc.id;
      final memberSnap = await _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('members')
          .doc(uid)
          .get();
      if (!memberSnap.exists || memberSnap.data() == null) continue;

      final membership =
          OrganizationMembership.fromMap(uid, memberSnap.data()!);
      if (membership.groupIds.isEmpty) continue;

      final orgSnap = await _firestore.collection('organizations').doc(orgId).get();
      final orgName = orgSnap.data()?['name'] as String? ?? '';

      for (final groupId in membership.groupIds) {
        final groupSnap = await _firestore
            .collection('organizations')
            .doc(orgId)
            .collection('groups')
            .doc(groupId)
            .get();
        if (!groupSnap.exists || groupSnap.data() == null) continue;
        final group = MinistryGroup.fromMap(
          groupSnap.id,
          groupSnap.data()!,
          organizationId: orgId,
        );
        groups.add(
          ShareableGroup(
            organizationId: orgId,
            organizationName: orgName,
            groupId: group.id,
            groupName: group.name,
          ),
        );
      }
    }

    groups.sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
    return groups;
  }

  /// Keeps the personal index in sync when group membership changes.
  Future<void> upsertGroupMembershipIndex(ShareableGroup group) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _groupMembershipIndex(uid)!.doc(group.groupId).set(
          {
            ...group.toIndexMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  Future<void> removeGroupMembershipIndex(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _groupMembershipIndex(uid)!.doc(groupId).delete();
  }
}
