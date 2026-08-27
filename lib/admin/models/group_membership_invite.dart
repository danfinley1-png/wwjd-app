import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupInviteStatus {
  pending,
  accepted,
  rejected,
}

extension GroupInviteStatusFirestore on GroupInviteStatus {
  String get firestoreValue {
    switch (this) {
      case GroupInviteStatus.pending:
        return 'pending';
      case GroupInviteStatus.accepted:
        return 'accepted';
      case GroupInviteStatus.rejected:
        return 'rejected';
    }
  }
}

GroupInviteStatus groupInviteStatusFromFirestore(String? value) {
  switch (value) {
    case 'accepted':
      return GroupInviteStatus.accepted;
    case 'rejected':
      return GroupInviteStatus.rejected;
    case 'pending':
    default:
      return GroupInviteStatus.pending;
  }
}

/// Consent-based invitation to join a group within an organization.
class GroupMembershipInvite {
  const GroupMembershipInvite({
    required this.id,
    required this.organizationId,
    required this.groupId,
    required this.groupName,
    required this.inviteeUid,
    required this.inviteeEmail,
    required this.invitedByUid,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.organizationName,
  });

  final String id;
  final String organizationId;
  final String groupId;
  final String groupName;
  final String inviteeUid;
  final String inviteeEmail;
  final String invitedByUid;
  final GroupInviteStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? organizationName;

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'groupId': groupId,
      'groupName': groupName,
      'inviteeUid': inviteeUid,
      'inviteeEmail': inviteeEmail,
      'invitedByUid': invitedByUid,
      'status': status.firestoreValue,
      'createdAt': Timestamp.fromDate(createdAt),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      if (organizationName != null) 'organizationName': organizationName,
    };
  }

  factory GroupMembershipInvite.fromMap(String id, Map<String, dynamic> map) {
    return GroupMembershipInvite(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      groupName: map['groupName'] as String? ?? '',
      inviteeUid: map['inviteeUid'] as String? ?? '',
      inviteeEmail: map['inviteeEmail'] as String? ?? '',
      invitedByUid: map['invitedByUid'] as String? ?? '',
      status: groupInviteStatusFromFirestore(map['status'] as String?),
      createdAt: _readTimestamp(map['createdAt']) ?? DateTime.now(),
      respondedAt: _readTimestamp(map['respondedAt']),
      organizationName: map['organizationName'] as String?,
    );
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
