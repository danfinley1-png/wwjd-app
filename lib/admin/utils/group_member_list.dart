import '../models/admin_role.dart';
import '../models/group_membership_invite.dart';
import '../models/organization_invite.dart';
import '../models/organization_membership.dart';

/// Membership status shown in group roster (includes consent invitations).
enum GroupMemberListStatus { accepted, pending, pendingOrgInvite, rejected }

class GroupMemberListEntry {
  const GroupMemberListEntry({
    required this.displayName,
    required this.email,
    required this.role,
    required this.status,
  });

  final String displayName;
  final String? email;
  final AdminRole role;
  final GroupMemberListStatus status;
}

/// Builds a unified group roster from active members and invitations.
List<GroupMemberListEntry> buildGroupMemberList({
  required List<OrganizationMembership> members,
  required List<GroupMembershipInvite> invites,
  required String groupId,
  List<OrganizationInvite> orgInvites = const [],
}) {
  final rows = <GroupMemberListEntry>[];
  final memberByUid = {for (final m in members) m.uid: m};
  final emailsInRows = <String>{};

  for (final member in members) {
    if (!member.groupIds.contains(groupId)) continue;
    final email = member.email?.toLowerCase();
    if (email != null && email.isNotEmpty) {
      emailsInRows.add(email);
    }
    rows.add(
      GroupMemberListEntry(
        displayName: member.displayName ?? member.email ?? 'Member',
        email: member.email,
        role: member.role,
        status: GroupMemberListStatus.accepted,
      ),
    );
  }

  final acceptedUids = members
      .where((m) => m.groupIds.contains(groupId))
      .map((m) => m.uid)
      .toSet();

  for (final invite in invites) {
    if (invite.groupId != groupId) continue;

    if (acceptedUids.contains(invite.inviteeUid) &&
        invite.status != GroupInviteStatus.rejected) {
      continue;
    }

    final member = memberByUid[invite.inviteeUid];
    final status = switch (invite.status) {
      GroupInviteStatus.pending => GroupMemberListStatus.pending,
      GroupInviteStatus.accepted => GroupMemberListStatus.accepted,
      GroupInviteStatus.rejected => GroupMemberListStatus.rejected,
    };

    final inviteEmail = invite.inviteeEmail.isNotEmpty
        ? invite.inviteeEmail
        : member?.email;
    final emailLower = inviteEmail?.toLowerCase();
    if (emailLower != null && emailLower.isNotEmpty) {
      emailsInRows.add(emailLower);
    }
    rows.add(
      GroupMemberListEntry(
        displayName: member?.displayName ??
            (invite.inviteeEmail.isNotEmpty
                ? invite.inviteeEmail
                : 'Invited member'),
        email: inviteEmail,
        role: member?.role ?? AdminRole.member,
        status: status,
      ),
    );
  }

  for (final orgInvite in orgInvites) {
    if (orgInvite.status != InviteStatus.pending) continue;
    if (!orgInvite.groupIds.contains(groupId)) continue;

    final emailLower = orgInvite.email.trim().toLowerCase();
    if (emailLower.isEmpty) continue;

    final alreadyInGroup = members.any(
      (m) =>
          m.groupIds.contains(groupId) &&
          m.email?.trim().toLowerCase() == emailLower,
    );
    if (alreadyInGroup || emailsInRows.contains(emailLower)) continue;

    emailsInRows.add(emailLower);
    rows.add(
      GroupMemberListEntry(
        displayName: orgInvite.email,
        email: orgInvite.email,
        role: orgInvite.role,
        status: GroupMemberListStatus.pendingOrgInvite,
      ),
    );
  }

  rows.sort((a, b) {
    final statusOrder = a.status.index.compareTo(b.status.index);
    if (statusOrder != 0) return statusOrder;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });

  return rows;
}

int pendingGroupInviteCount({
  required List<GroupMembershipInvite> invites,
  required String groupId,
}) {
  return invites
      .where(
        (i) => i.groupId == groupId && i.status == GroupInviteStatus.pending,
      )
      .length;
}

int pendingOrgInviteCountForGroup({
  required List<OrganizationInvite> orgInvites,
  required String groupId,
}) {
  return orgInvites
      .where(
        (i) =>
            i.status == InviteStatus.pending && i.groupIds.contains(groupId),
      )
      .length;
}

/// Pending invitations shown on the group roster (group consent + org email).
int pendingRosterCountForGroup({
  required List<OrganizationMembership> members,
  required List<GroupMembershipInvite> groupInvites,
  required List<OrganizationInvite> orgInvites,
  required String groupId,
}) {
  return buildGroupMemberList(
    members: members,
    invites: groupInvites,
    groupId: groupId,
    orgInvites: orgInvites,
  )
      .where(
        (r) =>
            r.status == GroupMemberListStatus.pending ||
            r.status == GroupMemberListStatus.pendingOrgInvite,
      )
      .length;
}
