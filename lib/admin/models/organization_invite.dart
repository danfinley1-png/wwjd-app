import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_role.dart';

enum InviteStatus {
  pending,
  accepted,
  revoked,
}

extension InviteStatusLabels on InviteStatus {
  String get firestoreValue {
    switch (this) {
      case InviteStatus.pending:
        return 'pending';
      case InviteStatus.accepted:
        return 'accepted';
      case InviteStatus.revoked:
        return 'revoked';
    }
  }
}

InviteStatus inviteStatusFromFirestore(String? value) {
  switch (value) {
    case 'accepted':
      return InviteStatus.accepted;
    case 'revoked':
      return InviteStatus.revoked;
    default:
      return InviteStatus.pending;
  }
}

/// Email invite to join an organization or group.
class OrganizationInvite {
  const OrganizationInvite({
    required this.id,
    required this.organizationId,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    this.groupIds = const [],
    this.invitedByUid,
    this.organizationName,
  });

  final String id;
  final String organizationId;
  final String email;
  final AdminRole role;
  final InviteStatus status;
  final DateTime createdAt;
  final List<String> groupIds;
  final String? invitedByUid;
  final String? organizationName;

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'email': email,
      'role': role.firestoreValue,
      'status': status.firestoreValue,
      'createdAt': Timestamp.fromDate(createdAt),
      'groupIds': groupIds,
      if (invitedByUid != null) 'invitedByUid': invitedByUid,
      if (organizationName != null) 'organizationName': organizationName,
    };
  }

  factory OrganizationInvite.fromMap(String id, Map<String, dynamic> map) {
    final rawGroups = map['groupIds'];
    return OrganizationInvite(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: adminRoleFromFirestore(map['role'] as String?),
      status: inviteStatusFromFirestore(map['status'] as String?),
      createdAt: _readTimestamp(map['createdAt']) ?? DateTime.now(),
      groupIds: rawGroups is List
          ? rawGroups.map((e) => e.toString()).toList()
          : const [],
      invitedByUid: map['invitedByUid'] as String?,
      organizationName: map['organizationName'] as String?,
    );
  }

  /// Human-readable organization name for member-facing UI.
  String get profileOrganizationLabel {
    final name = organizationName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Organization invitation';
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
