import '../models/admin_role.dart';
import '../models/ministry_group.dart';

/// Who may create, update, or share group-owned My Gifts for a group.
class GroupGiftShareAccess {
  const GroupGiftShareAccess._();

  /// Org admins (and overall admins, via [isOrgAdmin]) may manage every group.
  /// Group leaders may manage only groups in their membership [memberGroupIds].
  static bool canManageGroupGifts({
    required bool isOrgAdmin,
    required AdminRole? role,
    required List<String> memberGroupIds,
    required String groupId,
  }) {
    if (isOrgAdmin) return true;
    if (groupId.isEmpty) return false;
    return role == AdminRole.groupLeader && memberGroupIds.contains(groupId);
  }

  /// Other groups in the same organization the user may share a Gift into.
  static List<MinistryGroup> shareableTargetGroups({
    required List<MinistryGroup> allGroups,
    required String sourceGroupId,
    required bool isOrgAdmin,
    required AdminRole? role,
    required List<String> memberGroupIds,
  }) {
    return allGroups
        .where((group) => group.id != sourceGroupId)
        .where(
          (group) => canManageGroupGifts(
            isOrgAdmin: isOrgAdmin,
            role: role,
            memberGroupIds: memberGroupIds,
            groupId: group.id,
          ),
        )
        .toList();
  }
}
