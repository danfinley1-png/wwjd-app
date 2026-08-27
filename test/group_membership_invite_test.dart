import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/models/group_membership_invite.dart';

void main() {
  group('GroupMembershipInvite', () {
    test('round-trips through map', () {
      final created = DateTime(2026, 1, 15, 12);
      final invite = GroupMembershipInvite(
        id: 'inv1',
        organizationId: 'org1',
        groupId: 'grp1',
        groupName: 'Youth Group',
        inviteeUid: 'user1',
        inviteeEmail: 'user@example.com',
        invitedByUid: 'admin1',
        status: GroupInviteStatus.pending,
        createdAt: created,
        organizationName: 'St. Mary',
      );

      final map = invite.toMap();
      final restored = GroupMembershipInvite.fromMap('inv1', map);

      expect(restored.id, invite.id);
      expect(restored.groupName, 'Youth Group');
      expect(restored.status, GroupInviteStatus.pending);
      expect(restored.organizationName, 'St. Mary');
    });

    test('parses status from firestore values', () {
      expect(groupInviteStatusFromFirestore('pending'), GroupInviteStatus.pending);
      expect(groupInviteStatusFromFirestore('accepted'), GroupInviteStatus.accepted);
      expect(groupInviteStatusFromFirestore('rejected'), GroupInviteStatus.rejected);
    });
  });
}
