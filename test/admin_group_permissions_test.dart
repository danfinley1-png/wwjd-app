import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/models/admin_role.dart';

void main() {
  group('AdminRole group management', () {
    test('orgAdmin and groupLeader can manage groups', () {
      expect(AdminRole.orgAdmin.canManageGroups, isTrue);
      expect(AdminRole.groupLeader.canManageGroups, isTrue);
      expect(AdminRole.member.canManageGroups, isFalse);
    });
  });
}
