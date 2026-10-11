import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical group-owned My Gifts activity (e.g. Live Vertical).
///
/// Member copies live at `users/{uid}/gifts/{id}` and must not expose
/// anyone else's private spiritual content.
class GroupGift {
  const GroupGift({
    required this.id,
    required this.organizationId,
    required this.groupId,
    required this.title,
    required this.description,
    required this.frequency,
    required this.createdByUid,
    required this.createdAt,
    this.groupName,
    this.organizationName,
    this.linkedPrayerId,
    this.specificTime,
    this.daysOfWeek = const [],
    this.active = true,
    this.logoUrl,
    this.sharedFromGiftId,
    this.sharedFromGroupId,
    this.sortOrder,
    this.updatedAt,
  });

  static const frequencies = ['Daily', 'Weekly', 'Monthly', 'One-time'];

  final String id;
  final String organizationId;
  final String groupId;
  final String? groupName;
  final String? organizationName;
  final String title;
  final String description;
  final String? linkedPrayerId;
  final String frequency;
  /// Optional default time in 24h `HH:mm` format.
  final String? specificTime;
  final List<String> daysOfWeek;
  final bool active;
  final String? logoUrl;
  /// Original gift id when this definition was shared from another group.
  final String? sharedFromGiftId;
  final String? sharedFromGroupId;
  /// Display order chosen by an administrator. Lower comes first.
  final int? sortOrder;
  final String createdByUid;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'groupId': groupId,
      if (groupName != null && groupName!.trim().isNotEmpty)
        'groupName': groupName!.trim(),
      if (organizationName != null && organizationName!.trim().isNotEmpty)
        'organizationName': organizationName!.trim(),
      'title': title.trim(),
      'description': description.trim(),
      if (linkedPrayerId != null && linkedPrayerId!.trim().isNotEmpty)
        'linkedPrayerId': linkedPrayerId!.trim(),
      'frequency': frequency,
      if (specificTime != null && specificTime!.trim().isNotEmpty)
        'specificTime': specificTime!.trim(),
      'daysOfWeek': daysOfWeek,
      'active': active,
      if (logoUrl != null && logoUrl!.trim().isNotEmpty)
        'logoUrl': logoUrl!.trim(),
      if (sharedFromGiftId != null && sharedFromGiftId!.trim().isNotEmpty)
        'sharedFromGiftId': sharedFromGiftId!.trim(),
      if (sharedFromGroupId != null && sharedFromGroupId!.trim().isNotEmpty)
        'sharedFromGroupId': sharedFromGroupId!.trim(),
      'createdByUid': createdByUid,
      'createdAt': Timestamp.fromDate(createdAt),
      if (sortOrder != null) 'sortOrder': sortOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// This Gift plus every shared copy in [all] that belongs to the same chain.
  ///
  /// Sharing stores `sharedFromGiftId` on the copy. Deleting from a copy still
  /// finds the original and the other copies.
  static List<GroupGift> sameGiftAcrossGroups(
    List<GroupGift> all,
    GroupGift seed,
  ) {
    final ids = <String>{seed.id};
    final seedParent = seed.sharedFromGiftId?.trim() ?? '';
    if (seedParent.isNotEmpty) ids.add(seedParent);

    var grew = true;
    while (grew) {
      grew = false;
      for (final gift in all) {
        final parent = gift.sharedFromGiftId?.trim() ?? '';
        final linked = ids.contains(gift.id) ||
            (parent.isNotEmpty && ids.contains(parent));
        if (!linked) continue;
        if (ids.add(gift.id)) grew = true;
        if (parent.isNotEmpty && ids.add(parent)) grew = true;
      }
    }
    return all.where((gift) => ids.contains(gift.id)).toList();
  }

  /// Saved order first. Gifts with no order stay newest-first.
  static int compareDisplay(GroupGift a, GroupGift b) {
    final ao = a.sortOrder;
    final bo = b.sortOrder;
    if (ao != null && bo != null && ao != bo) return ao.compareTo(bo);
    if (ao != null && bo == null) return -1;
    if (ao == null && bo != null) return 1;
    return b.createdAt.compareTo(a.createdAt);
  }

  factory GroupGift.fromMap(String id, Map<String, dynamic> map) {
    return GroupGift(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      groupName: map['groupName'] as String?,
      organizationName: map['organizationName'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      linkedPrayerId: map['linkedPrayerId'] as String?,
      frequency: map['frequency'] as String? ?? 'Daily',
      specificTime: map['specificTime'] as String?,
      daysOfWeek: (map['daysOfWeek'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      active: map['active'] as bool? ?? true,
      logoUrl: map['logoUrl'] as String?,
      sharedFromGiftId: map['sharedFromGiftId'] as String?,
      sharedFromGroupId: map['sharedFromGroupId'] as String?,
      createdByUid: map['createdByUid'] as String? ?? '',
      createdAt: _readTimestamp(map['createdAt']) ?? DateTime.now(),
      sortOrder: (map['sortOrder'] as num?)?.toInt(),
      updatedAt: _readTimestamp(map['updatedAt']),
    );
  }

  GroupGift copyWith({
    String? title,
    String? description,
    String? linkedPrayerId,
    String? frequency,
    String? specificTime,
    List<String>? daysOfWeek,
    bool? active,
    String? logoUrl,
    String? groupName,
    String? organizationName,
    String? sharedFromGiftId,
    String? sharedFromGroupId,
    int? sortOrder,
  }) {
    return GroupGift(
      id: id,
      organizationId: organizationId,
      groupId: groupId,
      groupName: groupName ?? this.groupName,
      organizationName: organizationName ?? this.organizationName,
      title: title ?? this.title,
      description: description ?? this.description,
      linkedPrayerId: linkedPrayerId ?? this.linkedPrayerId,
      frequency: frequency ?? this.frequency,
      specificTime: specificTime ?? this.specificTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      active: active ?? this.active,
      logoUrl: logoUrl ?? this.logoUrl,
      sharedFromGiftId: sharedFromGiftId ?? this.sharedFromGiftId,
      sharedFromGroupId: sharedFromGroupId ?? this.sharedFromGroupId,
      createdByUid: createdByUid,
      createdAt: createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt,
    );
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
