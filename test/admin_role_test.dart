import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/models/admin_role.dart';

void main() {
  group('AdminRole', () {
    test('orgAdmin can manage organization and view insights', () {
      const role = AdminRole.orgAdmin;
      expect(role.canManageOrganization, isTrue);
      expect(role.canManageGroups, isTrue);
      expect(role.canInviteMembers, isTrue);
      expect(role.canViewPastoralInsights, isTrue);
    });

    test('groupLeader can manage groups and view insights only', () {
      const role = AdminRole.groupLeader;
      expect(role.canManageOrganization, isFalse);
      expect(role.canManageGroups, isTrue);
      expect(role.canInviteMembers, isFalse);
      expect(role.canViewPastoralInsights, isTrue);
    });

    test('member has no admin capabilities', () {
      const role = AdminRole.member;
      expect(role.canManageOrganization, isFalse);
      expect(role.canManageGroups, isFalse);
      expect(role.canViewPastoralInsights, isFalse);
    });

    test('round-trips firestore values', () {
      expect(adminRoleFromFirestore('orgAdmin'), AdminRole.orgAdmin);
      expect(adminRoleFromFirestore('groupLeader'), AdminRole.groupLeader);
      expect(adminRoleFromFirestore('member'), AdminRole.member);
      expect(AdminRole.orgAdmin.firestoreValue, 'orgAdmin');
    });
  });
}
