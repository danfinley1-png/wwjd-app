/// Roles within an organization. Personal spiritual data is never tied to roles.
enum AdminRole {
  orgAdmin,
  groupLeader,
  member,
}

extension AdminRoleLabels on AdminRole {
  String get label {
    switch (this) {
      case AdminRole.orgAdmin:
        return 'Organization administrator';
      case AdminRole.groupLeader:
        return 'Group leader';
      case AdminRole.member:
        return 'Member';
    }
  }

  String get firestoreValue {
    switch (this) {
      case AdminRole.orgAdmin:
        return 'orgAdmin';
      case AdminRole.groupLeader:
        return 'groupLeader';
      case AdminRole.member:
        return 'member';
    }
  }

  bool get canManageOrganization => this == AdminRole.orgAdmin;

  /// Organization calendar events — org admin only (not group leaders).
  bool get canManageOrgCalendar => canManageOrganization;

  bool get canManageGroups =>
      this == AdminRole.orgAdmin || this == AdminRole.groupLeader;

  bool get canInviteMembers => canManageOrganization;

  bool get canViewPastoralInsights =>
      this == AdminRole.orgAdmin || this == AdminRole.groupLeader;
}

AdminRole adminRoleFromFirestore(String? value) {
  switch (value) {
    case 'orgAdmin':
      return AdminRole.orgAdmin;
    case 'groupLeader':
      return AdminRole.groupLeader;
    case 'member':
    default:
      return AdminRole.member;
  }
}
