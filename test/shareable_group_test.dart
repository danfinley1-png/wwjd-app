import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/models/shareable_group.dart';

void main() {
  group('ShareableGroup', () {
    test('round-trips index map', () {
      const group = ShareableGroup(
        organizationId: 'org1',
        organizationName: 'St. Mary Parish',
        groupId: 'grp1',
        groupName: 'Youth Group',
      );

      final restored = ShareableGroup.fromIndexMap(
        'grp1',
        group.toIndexMap(),
      );

      expect(restored.groupId, 'grp1');
      expect(restored.displayLabel, 'Youth Group · St. Mary Parish');
    });
  });
}
