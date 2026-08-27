import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/models/admin_role.dart';
import 'package:wwjd_app/admin/models/organization_invite.dart';
import 'package:wwjd_app/admin/models/group_membership_invite.dart';
import 'package:wwjd_app/admin/models/organization_membership.dart';
import 'package:wwjd_app/admin/utils/group_member_list.dart';

void main() {
  group('buildGroupMemberList', () {
    test('includes pending invites before acceptance', () {
      final members = [
        OrganizationMembership(
          uid: 'user1',
          organizationId: 'org1',
          role: AdminRole.member,
          joinedAt: DateTime(2026),
          email: 'active@example.com',
          groupIds: const ['grp1'],
        ),
        OrganizationMembership(
          uid: 'user2',
          organizationId: 'org1',
          role: AdminRole.groupLeader,
          joinedAt: DateTime(2026),
          email: 'pending@example.com',
          groupIds: const [],
        ),
      ];

      final invites = [
        GroupMembershipInvite(
          id: 'inv1',
          organizationId: 'org1',
          groupId: 'grp1',
          groupName: 'Youth',
          inviteeUid: 'user2',
          inviteeEmail: 'pending@example.com',
          invitedByUid: 'admin1',
          status: GroupInviteStatus.pending,
          createdAt: DateTime(2026),
        ),
      ];

      final rows = buildGroupMemberList(
        members: members,
        invites: invites,
        groupId: 'grp1',
      );

      expect(rows.length, 2);
      expect(rows.any((r) => r.displayName == 'active@example.com'), isTrue);
      expect(rows.any((r) => r.displayName == 'pending@example.com'), isTrue);

      final pending = rows.firstWhere(
        (r) => r.displayName == 'pending@example.com',
      );
      expect(pending.role, AdminRole.groupLeader);
      expect(pending.status, GroupMemberListStatus.pending);
    });

    test('includes pending org email invites assigned to the group', () {
      final orgInvites = [
        OrganizationInvite(
          id: 'org-inv1',
          organizationId: 'org1',
          email: 'newcomer@example.com',
          role: AdminRole.member,
          status: InviteStatus.pending,
          createdAt: DateTime(2026),
          groupIds: const ['grp1'],
        ),
        OrganizationInvite(
          id: 'org-inv2',
          organizationId: 'org1',
          email: 'other@example.com',
          role: AdminRole.member,
          status: InviteStatus.pending,
          createdAt: DateTime(2026),
          groupIds: const ['grp2'],
        ),
      ];

      final rows = buildGroupMemberList(
        members: const [],
        invites: const [],
        groupId: 'grp1',
        orgInvites: orgInvites,
      );

      expect(rows.length, 1);
      expect(rows.single.displayName, 'newcomer@example.com');
      expect(rows.single.status, GroupMemberListStatus.pendingOrgInvite);
    });
  });
}
