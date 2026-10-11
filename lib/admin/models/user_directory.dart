class DirectoryMembership {
  const DirectoryMembership({
    required this.id,
    required this.name,
    this.organizationId,
    this.organizationName,
  });

  final String id;
  final String name;
  final String? organizationId;
  final String? organizationName;

  String get label {
    final trimmed = name.trim();
    return trimmed;
  }

  factory DirectoryMembership.fromJson(Map<String, dynamic> json) {
    return DirectoryMembership(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String? ?? '').trim(),
      organizationId: json['organizationId'] as String?,
      organizationName: (json['organizationName'] as String?)?.trim(),
    );
  }
}

class DirectoryUser {
  const DirectoryUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.status,
    this.lastActive,
    this.createdAt,
    this.organizations = const [],
    this.groups = const [],
  });

  final String uid;
  final String email;
  final String displayName;
  final String status;
  final DateTime? lastActive;
  final DateTime? createdAt;
  final List<DirectoryMembership> organizations;
  final List<DirectoryMembership> groups;

  bool get isUnaffiliated => organizations.isEmpty && groups.isEmpty;

  String get nameLabel {
    final name = displayName.trim();
    return name.isNotEmpty ? name : '—';
  }

  String get organizationLabels {
    final names = organizations.map((e) => e.label).where((e) => e.isNotEmpty);
    return names.isEmpty ? '—' : names.join(', ');
  }

  String get groupLabels {
    final names = groups.map((e) => e.label).where((e) => e.isNotEmpty);
    return names.isEmpty ? '—' : names.join(', ');
  }

  factory DirectoryUser.fromJson(Map<String, dynamic> json) {
    return DirectoryUser(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      status: json['status'] as String? ?? 'registered',
      lastActive: _readDate(json['lastActive']),
      createdAt: _readDate(json['createdAt']),
      organizations: _memberships(json['organizations']),
      groups: _memberships(json['groups']),
    );
  }
}

class DirectoryPendingInvite {
  const DirectoryPendingInvite({
    required this.id,
    required this.kind,
    required this.email,
    this.displayName,
    this.createdAt,
    this.organizationId,
    this.organizationName,
    this.groupId,
    this.groupName,
    this.hasAccount = false,
  });

  final String id;
  final String kind;
  final String email;
  final String? displayName;
  final DateTime? createdAt;
  final String? organizationId;
  final String? organizationName;
  final String? groupId;
  final String? groupName;
  final bool hasAccount;

  String get nameLabel {
    final name = displayName?.trim() ?? '';
    return name.isNotEmpty ? name : '—';
  }

  String get kindLabel {
    switch (kind) {
      case 'platform':
        return 'WWJD-DI';
      case 'org':
        return 'Organization';
      case 'group':
        return 'Group';
      default:
        return kind;
    }
  }

  String get organizationLabels {
    final name = organizationName?.trim() ?? '';
    return name.isEmpty ? '—' : name;
  }

  String get groupLabels {
    final name = groupName?.trim() ?? '';
    return name.isEmpty ? '—' : name;
  }

  factory DirectoryPendingInvite.fromJson(Map<String, dynamic> json) {
    return DirectoryPendingInvite(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      createdAt: _readDate(json['createdAt']),
      organizationId: json['organizationId'] as String?,
      organizationName: json['organizationName'] as String?,
      groupId: json['groupId'] as String?,
      groupName: json['groupName'] as String?,
      hasAccount: json['hasAccount'] as bool? ?? false,
    );
  }
}

class UserDirectory {
  const UserDirectory({
    required this.generatedAt,
    required this.guestCount,
    required this.users,
    required this.pendingInvites,
    required this.organizations,
    required this.groups,
    this.note,
  });

  final DateTime generatedAt;
  final int guestCount;
  final List<DirectoryUser> users;
  final List<DirectoryPendingInvite> pendingInvites;
  final List<DirectoryMembership> organizations;
  final List<DirectoryMembership> groups;
  final String? note;

  List<DirectoryUser> get unaffiliatedUsers =>
      users.where((user) => user.isUnaffiliated).toList();

  factory UserDirectory.fromJson(Map<String, dynamic> json) {
    return UserDirectory(
      generatedAt: _readDate(json['generatedAt']) ?? DateTime.now(),
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 0,
      users: (json['users'] as List<dynamic>? ?? const [])
          .map((e) => DirectoryUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingInvites: (json['pendingInvites'] as List<dynamic>? ?? const [])
          .map(
            (e) => DirectoryPendingInvite.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      organizations: _memberships(json['organizations']),
      groups: _memberships(json['groups']),
      note: json['note'] as String?,
    );
  }
}

List<DirectoryMembership> _memberships(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => DirectoryMembership.fromJson(Map<String, dynamic>.from(e)))
      .where((e) => e.label.isNotEmpty)
      .toList();
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
