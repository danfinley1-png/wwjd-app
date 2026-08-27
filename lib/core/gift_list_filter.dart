import '../models/gift_activity.dart';
import '../models/group_practice_instance.dart';

/// Member-facing Sharing My Gifts filter: All, Personal, Organization, Group.
enum GiftFilterKind { all, personal, organization, group }

class GiftListFilter {
  const GiftListFilter.all()
      : kind = GiftFilterKind.all,
        organizationId = null,
        groupId = null;

  const GiftListFilter.personal()
      : kind = GiftFilterKind.personal,
        organizationId = null,
        groupId = null;

  const GiftListFilter.organization(this.organizationId)
      : kind = GiftFilterKind.organization,
        groupId = null;

  const GiftListFilter.group(this.groupId)
      : kind = GiftFilterKind.group,
        organizationId = null;

  final GiftFilterKind kind;
  final String? organizationId;
  final String? groupId;

  bool matchesGift(GiftActivity gift) {
    switch (kind) {
      case GiftFilterKind.all:
        return true;
      case GiftFilterKind.personal:
        return gift.isPersonal;
      case GiftFilterKind.organization:
        return organizationId != null &&
            organizationId!.isNotEmpty &&
            gift.organizationId == organizationId;
      case GiftFilterKind.group:
        return groupId != null &&
            groupId!.isNotEmpty &&
            gift.groupId == groupId;
    }
  }

  bool matchesPractice(GroupPracticeInstance practice) {
    switch (kind) {
      case GiftFilterKind.all:
        return true;
      case GiftFilterKind.personal:
        return false;
      case GiftFilterKind.organization:
        return organizationId != null &&
            organizationId!.isNotEmpty &&
            practice.organizationId == organizationId;
      case GiftFilterKind.group:
        return groupId != null &&
            groupId!.isNotEmpty &&
            practice.groupId == groupId;
    }
  }

  List<GiftActivity> applyToGifts(List<GiftActivity> gifts) =>
      gifts.where(matchesGift).toList();

  List<GroupPracticeInstance> applyToPractices(
    List<GroupPracticeInstance> practices,
  ) =>
      practices.where(matchesPractice).toList();
}
