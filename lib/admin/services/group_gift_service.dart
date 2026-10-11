import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/platform_admin_claim.dart';
import '../../models/gift_activity.dart';
import '../../models/gift_status.dart';
import '../config/admin_config.dart';
import '../models/admin_role.dart';
import '../models/group_gift.dart';
import '../models/ministry_group.dart';
import '../models/organization_membership.dart';
import '../utils/group_gift_share_access.dart';

/// One group Gift definition inside an organization.
class OrganizationGiftEntry {
  const OrganizationGiftEntry({
    required this.group,
    required this.gift,
  });

  final MinistryGroup group;
  final GroupGift gift;
}

/// Outcome of copying a group Gift into other groups in the same organization.
class GroupGiftShareResult {
  const GroupGiftShareResult({
    required this.sharedCount,
    required this.skippedCount,
    required this.sharedGroupNames,
    required this.skippedGroupNames,
  });

  final int sharedCount;
  final int skippedCount;
  final List<String> sharedGroupNames;
  final List<String> skippedGroupNames;
}

/// Creates group-owned My Gifts definitions and syncs copies to accepted members.
///
/// Never reads chat, reflections, history, or personal (non-group) gifts.
class GroupGiftService {
  GroupGiftService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _gifts(String orgId, String groupId) =>
      _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('groups')
          .doc(groupId)
          .collection('gifts');

  CollectionReference<Map<String, dynamic>>? _userGifts(String uid) =>
      _firestore.collection('users').doc(uid).collection('gifts');

  Stream<List<GroupGift>> watchGifts({
    required String orgId,
    required String groupId,
  }) {
    return _gifts(orgId, groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final gifts = snap.docs
              .map((doc) => GroupGift.fromMap(doc.id, doc.data()))
              .toList();
          gifts.sort(GroupGift.compareDisplay);
          return gifts;
        });
  }

  Future<String> createGift({
    required String orgId,
    required MinistryGroup group,
    required String organizationName,
    required String title,
    required String description,
    required String frequency,
    String? linkedPrayerId,
    String? specificTime,
    List<String> daysOfWeek = const [],
    bool active = true,
    String? sharedFromGiftId,
    String? sharedFromGroupId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Sign in required.');
    await _assertCanManageGroupGifts(orgId, group.id);

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) throw Exception('Title is required.');
    final trimmedDescription = description.trim();
    if (trimmedDescription.isEmpty) throw Exception('Description is required.');
    if (!GroupGift.frequencies.contains(frequency)) {
      throw Exception('Choose a valid frequency.');
    }

    final ref = _gifts(orgId, group.id).doc();
    final orgLogo = await _logoUrlForOrg(orgId);
    final sortOrder = await _nextSortOrder(orgId, group.id);
    final gift = GroupGift(
      id: ref.id,
      organizationId: orgId,
      groupId: group.id,
      groupName: group.name,
      organizationName: organizationName,
      title: trimmedTitle,
      description: trimmedDescription,
      linkedPrayerId: linkedPrayerId?.trim().isEmpty == true
          ? null
          : linkedPrayerId?.trim(),
      frequency: frequency,
      specificTime: specificTime?.trim().isEmpty == true
          ? null
          : specificTime?.trim(),
      daysOfWeek: daysOfWeek,
      active: active,
      logoUrl: orgLogo ?? group.logoUrl,
      sharedFromGiftId: sharedFromGiftId?.trim().isEmpty == true
          ? null
          : sharedFromGiftId?.trim(),
      sharedFromGroupId: sharedFromGroupId?.trim().isEmpty == true
          ? null
          : sharedFromGroupId?.trim(),
      createdByUid: uid,
      createdAt: DateTime.now(),
      sortOrder: sortOrder,
    );

    try {
      await ref.set(gift.toMap());
    } catch (e) {
      throw Exception(
        'Could not save the group Gift definition (deploy latest Firestore '
        'rules if this is permission-denied): $e',
      );
    }
    if (active) {
      try {
        await _syncGiftToAcceptedMembers(gift);
      } catch (e) {
        throw Exception(
          'Group Gift was saved, but adding it to accepted members failed: $e',
        );
      }
    }
    return ref.id;
  }

  /// Persists the administrator's order. [orderedIds] is top to bottom.
  Future<void> reorderGifts({
    required String orgId,
    required String groupId,
    required List<String> orderedIds,
  }) async {
    await _assertCanManageGroupGifts(orgId, groupId);
    if (orderedIds.isEmpty) return;

    var batch = _firestore.batch();
    var ops = 0;

    Future<void> flush({bool force = false}) async {
      if (ops == 0) return;
      if (!force && ops < 400) return;
      await batch.commit();
      batch = _firestore.batch();
      ops = 0;
    }

    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_gifts(orgId, groupId).doc(orderedIds[i]), {
        'sortOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ops++;
      await flush();
    }

    await flush(force: true);

    // Do not read users/{uid}/gifts. Only the member may read that copy.
    // Update it directly; a missing copy is skipped.
    final members = await _acceptedMembers(orgId, groupId);
    for (final member in members) {
      final col = _userGifts(member.uid);
      if (col == null) continue;
      for (var i = 0; i < orderedIds.length; i++) {
        try {
          await col.doc(orderedIds[i]).update({
            'sortOrder': i,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseException catch (e) {
          if (e.code == 'not-found') continue;
          rethrow;
        }
      }
    }
  }

  Future<int?> _nextSortOrder(String orgId, String groupId) async {
    final snap = await _gifts(orgId, groupId).get();
    var maxOrder = -1;
    var any = false;
    for (final doc in snap.docs) {
      final raw = doc.data()['sortOrder'];
      if (raw is num) {
        any = true;
        if (raw.toInt() > maxOrder) maxOrder = raw.toInt();
      }
    }
    if (!any) return null;
    return maxOrder + 1;
  }

  Future<void> updateGift(GroupGift gift) async {
    await _assertCanManageGroupGifts(gift.organizationId, gift.groupId);
    final trimmedTitle = gift.title.trim();
    if (trimmedTitle.isEmpty) throw Exception('Title is required.');
    final trimmedDescription = gift.description.trim();
    if (trimmedDescription.isEmpty) throw Exception('Description is required.');

    final updated = gift.copyWith(
      title: trimmedTitle,
      description: trimmedDescription,
    );
    final map = updated.toMap();
    map.remove('createdAt');
    map.remove('createdByUid');
    final prayer = updated.linkedPrayerId?.trim() ?? '';
    if (prayer.isEmpty) {
      map['linkedPrayerId'] = FieldValue.delete();
    }
    final time = updated.specificTime?.trim() ?? '';
    if (time.isEmpty) {
      map['specificTime'] = FieldValue.delete();
    }
    await _gifts(updated.organizationId, updated.groupId)
        .doc(updated.id)
        .update(map);
    if (updated.active) {
      await _syncGiftToAcceptedMembers(updated, mergeProgress: true);
    }
  }

  Future<void> setActive({
    required GroupGift gift,
    required bool active,
  }) async {
    await _assertCanManageGroupGifts(gift.organizationId, gift.groupId);
    final updated = gift.copyWith(active: active);
    await _gifts(gift.organizationId, gift.groupId).doc(gift.id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (active) {
      await _syncGiftToAcceptedMembers(updated);
    } else {
      await _setMemberCopiesPaused(updated);
    }
  }

  /// Copies [gift] into other groups in the same organization.
  ///
  /// Org admins may share to any group. Group leaders may share only to groups
  /// they lead. Each target gets its own definition and member copies.
  Future<GroupGiftShareResult> shareGiftToGroups({
    required GroupGift gift,
    required List<MinistryGroup> targetGroups,
    required String organizationName,
  }) async {
    await _assertCanManageGroupGifts(gift.organizationId, gift.groupId);

    final sharedNames = <String>[];
    final skippedNames = <String>[];

    for (final target in targetGroups) {
      if (target.id == gift.groupId) {
        skippedNames.add(target.name);
        continue;
      }
      await _assertCanManageGroupGifts(gift.organizationId, target.id);

      final existing = await _gifts(gift.organizationId, target.id).get();
      final alreadyShared = existing.docs.any((doc) {
        final data = doc.data();
        return data['sharedFromGiftId'] == gift.id;
      });
      if (alreadyShared) {
        skippedNames.add(target.name);
        continue;
      }

      await createGift(
        orgId: gift.organizationId,
        group: target,
        organizationName: organizationName,
        title: gift.title,
        description: gift.description,
        frequency: gift.frequency,
        linkedPrayerId: gift.linkedPrayerId,
        specificTime: gift.specificTime,
        daysOfWeek: gift.daysOfWeek,
        active: gift.active,
        sharedFromGiftId: gift.id,
        sharedFromGroupId: gift.groupId,
      );
      sharedNames.add(target.name);
    }

    return GroupGiftShareResult(
      sharedCount: sharedNames.length,
      skippedCount: skippedNames.length,
      sharedGroupNames: sharedNames,
      skippedGroupNames: skippedNames,
    );
  }

  /// Called when a user accepts group membership — deliver active group Gifts.
  Future<void> syncGiftsForNewMember({
    required String orgId,
    required String groupId,
    required String memberUid,
  }) async {
    final snap =
        await _gifts(orgId, groupId).where('active', isEqualTo: true).get();
    if (snap.docs.isEmpty) return;

    final col = _userGifts(memberUid);
    if (col == null) return;

    var batch = _firestore.batch();
    var ops = 0;
    for (final doc in snap.docs) {
      final gift = GroupGift.fromMap(doc.id, doc.data());
      batch.set(
        col.doc(gift.id),
        _memberGiftPayload(gift, memberUid: memberUid),
        SetOptions(merge: true),
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

  /// Every group Gift in [orgId]. Group definitions only — not personal Gifts.
  Future<List<OrganizationGiftEntry>> loadGiftsForOrganization(
    String orgId,
  ) async {
    if (!await _isOverallAdmin()) {
      throw Exception(
        'Only an overall administrator can list Gifts across an organization.',
      );
    }
    final groupsSnap = await _firestore
        .collection('organizations')
        .doc(orgId)
        .collection('groups')
        .get();
    final entries = <OrganizationGiftEntry>[];
    for (final groupDoc in groupsSnap.docs) {
      final group = MinistryGroup.fromMap(groupDoc.id, groupDoc.data());
      final giftsSnap = await _gifts(orgId, group.id).get();
      final gifts = giftsSnap.docs
          .map((doc) => GroupGift.fromMap(doc.id, doc.data()))
          .toList()
        ..sort(GroupGift.compareDisplay);
      for (final gift in gifts) {
        entries.add(OrganizationGiftEntry(group: group, gift: gift));
      }
    }
    entries.sort((a, b) {
      final byGroup = a.group.name.toLowerCase().compareTo(
            b.group.name.toLowerCase(),
          );
      if (byGroup != 0) return byGroup;
      return GroupGift.compareDisplay(a.gift, b.gift);
    });
    return entries;
  }

  /// Deletes the group Gift and each accepted member's copy.
  /// Member copies are deleted by id. They are not read first.
  Future<void> deleteGift({
    required String orgId,
    required String groupId,
    required String giftId,
  }) async {
    await _assertCanManageGroupGifts(orgId, groupId);
    await _gifts(orgId, groupId).doc(giftId).delete();

    final members = await _acceptedMembers(orgId, groupId);
    for (final member in members) {
      final col = _userGifts(member.uid);
      if (col == null) continue;
      try {
        await col.doc(giftId).delete();
      } on FirebaseException catch (e) {
        if (e.code == 'not-found') continue;
        rethrow;
      }
    }
  }

  /// Deletes this Gift from every group in the organization that shares it.
  ///
  /// Overall administrator only. Personal Gifts are left in place.
  Future<int> deleteGiftAcrossOrganization({
    required String orgId,
    required GroupGift gift,
  }) async {
    if (!await _isOverallAdmin()) {
      throw Exception(
        'Only an overall administrator can delete a Gift for the whole organization.',
      );
    }
    final entries = await loadGiftsForOrganization(orgId);
    final family = GroupGift.sameGiftAcrossGroups(
      entries.map((entry) => entry.gift).toList(),
      gift,
    );
    final targets = family.isEmpty ? [gift] : family;
    for (final target in targets) {
      await deleteGift(
        orgId: orgId,
        groupId: target.groupId,
        giftId: target.id,
      );
    }
    return targets.length;
  }

  /// Removes synced group Gifts when a member leaves a group.
  Future<void> removeGiftsForMember({
    required String orgId,
    required String groupId,
    required String memberUid,
  }) async {
    final col = _userGifts(memberUid);
    if (col == null) return;

    final snap = await col.where('groupId', isEqualTo: groupId).get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    var deletes = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['source'] != GiftActivitySource.groupGift) continue;
      if ((data['organizationId'] as String? ?? '') != orgId) continue;
      batch.delete(doc.reference);
      deletes++;
    }
    if (deletes > 0) await batch.commit();
  }

  Future<void> _syncGiftToAcceptedMembers(
    GroupGift gift, {
    bool mergeProgress = true,
  }) async {
    final members =
        await _acceptedMembers(gift.organizationId, gift.groupId);
    if (members.isEmpty) return;

    var batch = _firestore.batch();
    var ops = 0;

    for (final member in members) {
      final col = _userGifts(member.uid);
      if (col == null) continue;
      batch.set(
        col.doc(gift.id),
        _memberGiftPayload(gift, memberUid: member.uid),
        SetOptions(merge: mergeProgress),
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

  Future<void> _setMemberCopiesPaused(GroupGift gift) async {
    final members =
        await _acceptedMembers(gift.organizationId, gift.groupId);
    if (members.isEmpty) return;

    var batch = _firestore.batch();
    var ops = 0;
    for (final member in members) {
      final col = _userGifts(member.uid);
      if (col == null) continue;
      batch.set(
        col.doc(gift.id),
        {
          'status': GiftStatus.paused.firestoreValue,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
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

  Map<String, dynamic> _memberGiftPayload(
    GroupGift gift, {
    required String memberUid,
  }) {
    final time = gift.specificTime?.trim();
    return {
      'id': gift.id,
      'title': gift.title,
      'description': gift.description,
      if (gift.linkedPrayerId != null && gift.linkedPrayerId!.trim().isNotEmpty)
        'linkedPrayerId': gift.linkedPrayerId!.trim(),
      'frequency': gift.frequency,
      if (time != null && time.isNotEmpty) 'specificTime': time,
      'daysOfWeek': gift.daysOfWeek,
      'hasReminder': time != null && time.isNotEmpty,
      'userId': memberUid,
      'source': GiftActivitySource.groupGift,
      'groupGiftId': gift.id,
      'groupId': gift.groupId,
      if (gift.groupName != null) 'groupName': gift.groupName,
      'organizationId': gift.organizationId,
      if (gift.organizationName != null)
        'organizationName': gift.organizationName,
      if (gift.logoUrl != null && gift.logoUrl!.trim().isNotEmpty)
        'groupLogoUrl': gift.logoUrl!.trim(),
      'status': gift.active
          ? GiftStatus.active.firestoreValue
          : GiftStatus.paused.firestoreValue,
      'createdAt': Timestamp.fromDate(gift.createdAt),
      if (gift.sortOrder != null) 'sortOrder': gift.sortOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<bool> _isOverallAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (AdminConfig.isFoundationAdmin(user.email)) return true;
    try {
      final token = await user.getIdTokenResult();
      if (PlatformAdminClaim.hasAdminClaim(token.claims)) return true;
    } catch (_) {
      // Claim lookup can fail offline. The platformAdmins document is next.
    }
    final snap =
        await _firestore.collection('platformAdmins').doc(user.uid).get();
    if (!snap.exists) return false;
    final role = snap.data()?['role']?.toString() ?? '';
    return role.isEmpty || role == 'superAdmin';
  }

  Future<void> _assertCanManageGroupGifts(String orgId, String groupId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Sign in required.');

    var isOrgAdmin = await _isOverallAdmin();
    if (!isOrgAdmin) {
      final platformSnap =
          await _firestore.collection('platformAdmins').doc(uid).get();
      isOrgAdmin = platformSnap.exists;
    }
    if (!isOrgAdmin) {
      final orgSnap =
          await _firestore.collection('organizations').doc(orgId).get();
      isOrgAdmin = orgSnap.data()?['createdByUid'] == uid;
    }

    OrganizationMembership? membership;
    final memberSnap = await _firestore
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(uid)
        .get();
    if (memberSnap.exists) {
      membership = OrganizationMembership.fromMap(uid, memberSnap.data()!);
      if (membership.role == AdminRole.orgAdmin) isOrgAdmin = true;
    }

    final allowed = GroupGiftShareAccess.canManageGroupGifts(
      isOrgAdmin: isOrgAdmin,
      role: membership?.role,
      memberGroupIds: membership?.groupIds ?? const [],
      groupId: groupId,
    );
    if (!allowed) {
      throw Exception(
        'This Gift can only be managed for groups you administer. '
        'Group leaders may share only to groups they lead.',
      );
    }
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

  Future<String?> _logoUrlForOrg(String orgId) async {
    final snap =
        await _firestore.collection('organizations').doc(orgId).get();
    final url = snap.data()?['logoUrl'] as String?;
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
