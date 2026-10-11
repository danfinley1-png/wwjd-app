import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/models/group_gift.dart';

void main() {
  GroupGift gift({
    required String id,
    required String groupId,
    String? sharedFromGiftId,
  }) {
    return GroupGift(
      id: id,
      organizationId: 'org',
      groupId: groupId,
      title: 'Morning offering',
      description: 'Offer the day',
      frequency: 'Daily',
      createdByUid: 'admin',
      createdAt: DateTime.utc(2026, 10, 1),
      sharedFromGiftId: sharedFromGiftId,
    );
  }

  test('organization delete includes the original and every shared copy', () {
    final original = gift(id: 'root', groupId: 'armor');
    final copy = gift(id: 'copy', groupId: 'youth', sharedFromGiftId: 'root');
    final grandchild = gift(
      id: 'copy-2',
      groupId: 'adults',
      sharedFromGiftId: 'copy',
    );
    final other = gift(id: 'other', groupId: 'armor');

    final fromCopy = GroupGift.sameGiftAcrossGroups(
      [original, copy, grandchild, other],
      copy,
    );

    expect(fromCopy.map((g) => g.id).toSet(), {'root', 'copy', 'copy-2'});
  });

  test('a group-only Gift stays one definition', () {
    final only = gift(id: 'solo', groupId: 'armor');
    final other = gift(id: 'other', groupId: 'youth');

    final family = GroupGift.sameGiftAcrossGroups([only, other], only);

    expect(family.map((g) => g.id), ['solo']);
  });
}
