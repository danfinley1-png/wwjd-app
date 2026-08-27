import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_role.dart';

/// Organizational membership — never grants access to personal spiritual data.
class OrganizationMembership {
  const OrganizationMembership({
    required this.uid,
    required this.organizationId,
    required this.role,
    required this.joinedAt,
    this.email,
    this.displayName,
    this.groupIds = const [],
    this.invitedByUid,
  });

  final String uid;
  final String organizationId;
  final AdminRole role;
  final DateTime joinedAt;
  final String? email;
  final String? displayName;
  final List<String> groupIds;
  final String? invitedByUid;

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'role': role.firestoreValue,
      'joinedAt': Timestamp.fromDate(joinedAt),
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      'groupIds': groupIds,
      if (invitedByUid != null) 'invitedByUid': invitedByUid,
    };
  }

  factory OrganizationMembership.fromMap(String uid, Map<String, dynamic> map) {
    final rawGroups = map['groupIds'];
    return OrganizationMembership(
      uid: uid,
      organizationId: map['organizationId'] as String? ?? '',
      role: adminRoleFromFirestore(map['role'] as String?),
      joinedAt: _readTimestamp(map['joinedAt']) ?? DateTime.now(),
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
      groupIds: rawGroups is List
          ? rawGroups.map((e) => e.toString()).toList()
          : const [],
      invitedByUid: map['invitedByUid'] as String?,
    );
  }

  OrganizationMembership copyWith({
    AdminRole? role,
    List<String>? groupIds,
    String? displayName,
  }) {
    return OrganizationMembership(
      uid: uid,
      organizationId: organizationId,
      role: role ?? this.role,
      joinedAt: joinedAt,
      email: email,
      displayName: displayName ?? this.displayName,
      groupIds: groupIds ?? this.groupIds,
      invitedByUid: invitedByUid,
    );
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
