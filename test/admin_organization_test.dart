import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/models/organization.dart';
import 'package:wwjd_app/admin/services/organization_service.dart';

void main() {
  group('OrganizationService', () {
    test('normalizeEmail lowercases and trims', () {
      expect(
        OrganizationService.normalizeEmail('  Leader@Parish.ORG  '),
        'leader@parish.org',
      );
    });

    test('mergeGroupIds unions without duplicates', () {
      expect(
        OrganizationService.mergeGroupIds(['g1', 'g2'], ['g2', 'g3']),
        ['g1', 'g2', 'g3'],
      );
    });
  });

  group('Organization model', () {
    test('serializes and deserializes', () {
      final now = DateTime(2026, 1, 15);
      final org = Organization(
        id: 'org1',
        name: 'St. Mary Parish',
        type: OrganizationType.parish,
        createdAt: now,
        createdByUid: 'uid1',
      );

      final map = org.toMap();
      final restored = Organization.fromMap('org1', map);

      expect(restored.name, 'St. Mary Parish');
      expect(restored.type, OrganizationType.parish);
      expect(restored.createdByUid, 'uid1');
    });
  });
}
