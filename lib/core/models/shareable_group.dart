/// A ministry group the current user belongs to and may share content into.
class ShareableGroup {
  const ShareableGroup({
    required this.organizationId,
    required this.organizationName,
    required this.groupId,
    required this.groupName,
  });

  final String organizationId;
  final String organizationName;
  final String groupId;
  final String groupName;

  /// User-facing label for share pickers — recognizable ministry names only.
  String get userFacingLabel {
    final group = groupName.trim();
    final org = organizationName.trim();
    if (group.isEmpty) return org;
    if (org.isEmpty) return group;
    if (group.toLowerCase() == org.toLowerCase()) return group;
    return '$org · $group';
  }

  /// Sort key for group lists (same as [userFacingLabel]).
  String get displayLabel => userFacingLabel;

  Map<String, dynamic> toIndexMap() {
    return {
      'organizationId': organizationId,
      'groupId': groupId,
      'groupName': groupName,
      'organizationName': organizationName,
    };
  }

  factory ShareableGroup.fromIndexMap(String groupId, Map<String, dynamic> map) {
    return ShareableGroup(
      organizationId: map['organizationId'] as String? ?? '',
      organizationName: map['organizationName'] as String? ?? '',
      groupId: groupId,
      groupName: map['groupName'] as String? ?? '',
    );
  }
}
