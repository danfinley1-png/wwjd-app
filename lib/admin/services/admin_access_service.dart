import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/admin_config.dart';
import '../models/admin_role.dart';
import '../models/organization_invite.dart';
import 'organization_service.dart';

/// Result of checking whether the signed-in user may enter the Admin area.
enum AdminAccessStatus {
  /// Org admin, group leader, pending leader invite, or bootstrap (no org yet).
  authorized,

  /// In an organization as a member only — not a leader.
  memberOnly,

  /// Not signed in.
  unauthenticated,

  /// Anonymous guest accounts cannot use the Admin area.
  guestNotAllowed,
}

class AdminAccessService {
  AdminAccessService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<AdminAccessStatus> evaluateAccess() async {
    final user = _auth.currentUser;
    if (user == null) return AdminAccessStatus.unauthenticated;
    if (user.isAnonymous) return AdminAccessStatus.guestNotAllowed;

    final email = user.email;
    if (AdminConfig.isFoundationAdmin(email)) {
      return AdminAccessStatus.authorized;
    }

    final uid = user.uid;
    final membershipSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('orgMemberships')
        .get();

    var hasLeaderMembership = false;
    var hasAnyMembership = membershipSnap.docs.isNotEmpty;

    for (final doc in membershipSnap.docs) {
      final role = adminRoleFromFirestore(doc.data()['role'] as String?);
      if (role.canViewPastoralInsights) {
        hasLeaderMembership = true;
        break;
      }
    }

    if (hasLeaderMembership) return AdminAccessStatus.authorized;

    if (email != null && email.isNotEmpty) {
      final pendingLeaderInvite = await _hasPendingLeaderInvite(email);
      if (pendingLeaderInvite) return AdminAccessStatus.authorized;
    }

    if (hasAnyMembership) return AdminAccessStatus.memberOnly;

    // Signed-in user with no org yet — bootstrap path to create an organization.
    return AdminAccessStatus.authorized;
  }

  Future<bool> _hasPendingLeaderInvite(String email) async {
    final snap = await _firestore
        .collection('emailInvites')
        .doc(OrganizationService.normalizeEmail(email))
        .collection('items')
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in snap.docs) {
      final invite = OrganizationInvite.fromMap(doc.id, doc.data());
      if (invite.role.canViewPastoralInsights) return true;
    }
    return false;
  }

  Stream<AdminAccessStatus> watchAccess() async* {
    yield await evaluateAccess();
  }
}

String adminAccessDeniedMessage(AdminAccessStatus status) {
  switch (status) {
    case AdminAccessStatus.memberOnly:
      return 'This area is restricted to authorized organization administrators '
          'and group leaders. Your account is registered as an organization '
          'member only.';
    case AdminAccessStatus.guestNotAllowed:
      return 'Administrator sign-in requires a registered email account. '
          'Guest sessions cannot access the Admin area.';
    case AdminAccessStatus.unauthenticated:
      return 'Please sign in with your administrator credentials.';
    case AdminAccessStatus.authorized:
      return '';
  }
}
