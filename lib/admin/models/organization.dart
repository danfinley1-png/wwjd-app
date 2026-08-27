import 'package:cloud_firestore/cloud_firestore.dart';

enum OrganizationType {
  parish,
  school,
  ministry,
  other,
}

extension OrganizationTypeLabels on OrganizationType {
  String get label {
    switch (this) {
      case OrganizationType.parish:
        return 'Parish';
      case OrganizationType.school:
        return 'School';
      case OrganizationType.ministry:
        return 'Ministry';
      case OrganizationType.other:
        return 'Other';
    }
  }

  String get firestoreValue {
    switch (this) {
      case OrganizationType.parish:
        return 'parish';
      case OrganizationType.school:
        return 'school';
      case OrganizationType.ministry:
        return 'ministry';
      case OrganizationType.other:
        return 'other';
    }
  }
}

OrganizationType organizationTypeFromFirestore(String? value) {
  switch (value) {
    case 'parish':
      return OrganizationType.parish;
    case 'school':
      return OrganizationType.school;
    case 'ministry':
      return OrganizationType.ministry;
    default:
      return OrganizationType.other;
  }
}

/// A parish, school, or ministry institution using WWJD-DI.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.createdByUid,
    this.updatedAt,
    this.logoUrl,
  });

  final String id;
  final String name;
  final OrganizationType type;
  final DateTime createdAt;
  final String createdByUid;
  final DateTime? updatedAt;
  /// Organization-level brand image. Groups inherit this; they do not have their own logo.
  final String? logoUrl;

  /// Non-empty HTTPS / Storage URL, or null.
  String? get resolvedLogoUrl {
    final url = logoUrl?.trim();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  /// Prefer the organization logo; fall back to a stamped copy on a Gift or group.
  static String? resolveLogoUrl({
    String? organizationLogoUrl,
    String? fallback,
  }) {
    final org = organizationLogoUrl?.trim();
    if (org != null && org.isNotEmpty) return org;
    final fb = fallback?.trim();
    if (fb != null && fb.isNotEmpty) return fb;
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.firestoreValue,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdByUid': createdByUid,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (logoUrl != null && logoUrl!.trim().isNotEmpty) 'logoUrl': logoUrl!.trim(),
    };
  }

  factory Organization.fromMap(String id, Map<String, dynamic> map) {
    return Organization(
      id: id,
      name: map['name'] as String? ?? '',
      type: organizationTypeFromFirestore(map['type'] as String?),
      createdAt: _readTimestamp(map['createdAt']) ?? DateTime.now(),
      createdByUid: map['createdByUid'] as String? ?? '',
      updatedAt: _readTimestamp(map['updatedAt']),
      logoUrl: map['logoUrl'] as String?,
    );
  }

  Organization copyWith({
    String? name,
    OrganizationType? type,
    DateTime? updatedAt,
    String? logoUrl,
  }) {
    return Organization(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt,
      createdByUid: createdByUid,
      updatedAt: updatedAt ?? this.updatedAt,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
