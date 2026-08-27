import 'package:cloud_firestore/cloud_firestore.dart';

/// A group within an organization (e.g. youth group, confirmation class).
class MinistryGroup {
  const MinistryGroup({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.createdAt,
    this.ageBand,
    this.description,
    this.logoUrl,
  });

  final String id;
  final String organizationId;
  final String name;
  final DateTime createdAt;
  final String? ageBand;
  final String? description;
  /// Optional HTTPS image URL for group branding on shared Gifts.
  final String? logoUrl;

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (ageBand != null && ageBand!.isNotEmpty) 'ageBand': ageBand,
      if (description != null && description!.isNotEmpty) 'description': description,
      if (logoUrl != null && logoUrl!.isNotEmpty) 'logoUrl': logoUrl,
    };
  }

  factory MinistryGroup.fromMap(
    String id,
    Map<String, dynamic> map, {
    String? organizationId,
  }) {
    return MinistryGroup(
      id: id,
      organizationId: organizationId ?? map['organizationId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      createdAt: _readTimestamp(map['createdAt']) ?? DateTime.now(),
      ageBand: map['ageBand'] as String?,
      description: map['description'] as String?,
      logoUrl: map['logoUrl'] as String?,
    );
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
