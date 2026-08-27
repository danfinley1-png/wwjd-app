import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/models/group_gift.dart';
import 'package:wwjd_app/admin/models/admin_role.dart';
import 'package:wwjd_app/admin/models/ministry_group.dart';
import 'package:wwjd_app/admin/utils/group_gift_share_access.dart';
import 'package:wwjd_app/core/gift_list_filter.dart';
import 'package:wwjd_app/models/gift_activity.dart';
import 'package:wwjd_app/models/group_practice_instance.dart';
import 'package:wwjd_app/admin/models/group_schedule.dart';
import 'package:wwjd_app/admin/models/organization.dart';
import 'package:wwjd_app/widgets/group_brand_mark.dart';

void main() {
  GiftActivity personalGift() => GiftActivity(
        id: 'p1',
        title: 'Personal rosary',
        description: 'Pray in the morning',
        frequency: 'Daily',
        userId: 'u1',
      );

  GiftActivity groupGift() => GiftActivity(
        id: 'g1',
        title: 'Live Vertical offering',
        description: 'Morning offering with the group',
        frequency: 'Daily',
        userId: 'u1',
        source: GiftActivitySource.groupGift,
        groupGiftId: 'g1',
        groupId: 'live-vertical',
        groupName: 'Live Vertical',
        organizationId: 'org-1',
        organizationName: 'Campus Ministry',
        groupLogoUrl: 'https://example.com/lv.png',
      );

  GroupPracticeInstance practice() => GroupPracticeInstance(
        id: 's1',
        groupScheduleId: 's1',
        organizationId: 'org-1',
        groupId: 'live-vertical',
        title: 'Group Angelus',
        description: 'Pray the Angelus',
        times: const ['12:00'],
        recurrence: GroupScheduleRecurrence.daily,
        groupName: 'Live Vertical',
      );

  group('GiftActivity group branding', () {
    test('personal gifts stay distinct from group gifts', () {
      final personal = personalGift();
      final group = groupGift();

      expect(personal.isPersonal, isTrue);
      expect(personal.isGroupGift, isFalse);
      expect(personal.definitionLocked, isFalse);

      expect(group.isGroupGift, isTrue);
      expect(group.isPersonal, isFalse);
      expect(group.definitionLocked, isTrue);
      expect(group.brandLabel, 'Live Vertical');
    });

    test('fromMap keeps group source fields', () {
      final restored = GiftActivity.fromMap({
        'id': 'g1',
        'title': 'Live Vertical offering',
        'description': 'Morning offering with the group',
        'frequency': 'Daily',
        'source': 'groupGift',
        'groupGiftId': 'g1',
        'groupId': 'live-vertical',
        'groupName': 'Live Vertical',
        'organizationId': 'org-1',
        'organizationName': 'Campus Ministry',
        'groupLogoUrl': 'https://example.com/lv.png',
        'userId': 'u1',
      });

      expect(restored.source, GiftActivitySource.groupGift);
      expect(restored.groupId, 'live-vertical');
      expect(restored.organizationId, 'org-1');
      expect(restored.groupName, 'Live Vertical');
      expect(restored.groupLogoUrl, 'https://example.com/lv.png');
      expect(restored.definitionLocked, isTrue);
    });
  });

  group('GiftListFilter', () {
    test('All includes personal, group gifts, and group practices', () {
      const filter = GiftListFilter.all();
      expect(filter.matchesGift(personalGift()), isTrue);
      expect(filter.matchesGift(groupGift()), isTrue);
      expect(filter.matchesPractice(practice()), isTrue);
    });

    test('Personal excludes group-owned gifts and practices', () {
      const filter = GiftListFilter.personal();
      expect(filter.matchesGift(personalGift()), isTrue);
      expect(filter.matchesGift(groupGift()), isFalse);
      expect(filter.matchesPractice(practice()), isFalse);
    });

    test('By Organization matches only that org', () {
      const filter = GiftListFilter.organization('org-1');
      expect(filter.matchesGift(personalGift()), isFalse);
      expect(filter.matchesGift(groupGift()), isTrue);
      expect(filter.matchesPractice(practice()), isTrue);
      expect(
        const GiftListFilter.organization('other').matchesGift(groupGift()),
        isFalse,
      );
    });

    test('By Group matches only that group', () {
      const filter = GiftListFilter.group('live-vertical');
      expect(filter.matchesGift(personalGift()), isFalse);
      expect(filter.matchesGift(groupGift()), isTrue);
      expect(filter.matchesPractice(practice()), isTrue);
      expect(
        const GiftListFilter.group('other').matchesGift(groupGift()),
        isFalse,
      );
    });
  });

  group('Organization logo inheritance', () {
    test('resolveLogoUrl prefers organization over group fallback', () {
      expect(
        Organization.resolveLogoUrl(
          organizationLogoUrl: 'https://example.com/org.png',
          fallback: 'https://example.com/group.png',
        ),
        'https://example.com/org.png',
      );
    });

    test('resolveLogoUrl uses group fallback when org has no logo', () {
      expect(
        Organization.resolveLogoUrl(
          organizationLogoUrl: '  ',
          fallback: 'https://example.com/group.png',
        ),
        'https://example.com/group.png',
      );
    });

    test('fromMap reads logoUrl', () {
      final org = Organization.fromMap('o1', {
        'name': 'Campus Ministry',
        'type': 'ministry',
        'createdByUid': 'u1',
        'logoUrl': 'https://example.com/org.png',
      });
      expect(org.resolvedLogoUrl, 'https://example.com/org.png');
    });
  });

  group('GroupBrandMark', () {
    test('initials for Live Vertical', () {
      expect(GroupBrandMark.initialsFor('Live Vertical'), 'LV');
    });
  });

  group('GroupGift', () {
    test('fromMap reads active flag and branding', () {
      final gift = GroupGift.fromMap('id1', {
        'organizationId': 'org-1',
        'groupId': 'live-vertical',
        'groupName': 'Live Vertical',
        'title': 'Morning offering',
        'description': 'Pray together',
        'frequency': 'Daily',
        'active': true,
        'logoUrl': 'https://example.com/lv.png',
        'createdByUid': 'admin',
      });
      expect(gift.active, isTrue);
      expect(gift.logoUrl, 'https://example.com/lv.png');
      expect(gift.groupName, 'Live Vertical');
    });
  });

  group('GroupGiftShareAccess', () {
    MinistryGroup group(String id, String name) => MinistryGroup(
          id: id,
          organizationId: 'org-1',
          name: name,
          createdAt: DateTime(2026, 1, 1),
        );

    final liveVertical = group('live-vertical', 'Live Vertical');
    final confirmation = group('confirmation', 'Confirmation');
    final choir = group('choir', 'Choir');
    final allGroups = [liveVertical, confirmation, choir];

    test('org admin can share to every other group', () {
      final targets = GroupGiftShareAccess.shareableTargetGroups(
        allGroups: allGroups,
        sourceGroupId: 'live-vertical',
        isOrgAdmin: true,
        role: AdminRole.orgAdmin,
        memberGroupIds: const [],
      );
      expect(targets.map((g) => g.id), ['confirmation', 'choir']);
    });

    test('group leader can share only to groups they lead', () {
      final targets = GroupGiftShareAccess.shareableTargetGroups(
        allGroups: allGroups,
        sourceGroupId: 'live-vertical',
        isOrgAdmin: false,
        role: AdminRole.groupLeader,
        memberGroupIds: const ['live-vertical', 'confirmation'],
      );
      expect(targets.map((g) => g.id), ['confirmation']);
    });

    test('group leader cannot share to groups they do not lead', () {
      expect(
        GroupGiftShareAccess.canManageGroupGifts(
          isOrgAdmin: false,
          role: AdminRole.groupLeader,
          memberGroupIds: const ['live-vertical'],
          groupId: 'choir',
        ),
        isFalse,
      );
    });

    test('ordinary members cannot manage group gifts', () {
      expect(
        GroupGiftShareAccess.canManageGroupGifts(
          isOrgAdmin: false,
          role: AdminRole.member,
          memberGroupIds: const ['live-vertical', 'choir'],
          groupId: 'live-vertical',
        ),
        isFalse,
      );
    });
  });
}
