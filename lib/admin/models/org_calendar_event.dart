import 'package:cloud_firestore/cloud_firestore.dart';

/// School / organization calendar category. Distinct from personal Gifts.
enum OrgCalendarCategory {
  liturgy,
  academics,
  athletics,
  ministry,
  other,
}

extension OrgCalendarCategoryLabels on OrgCalendarCategory {
  String get label {
    switch (this) {
      case OrgCalendarCategory.liturgy:
        return 'Liturgy';
      case OrgCalendarCategory.academics:
        return 'Academics';
      case OrgCalendarCategory.athletics:
        return 'Athletics';
      case OrgCalendarCategory.ministry:
        return 'Ministry';
      case OrgCalendarCategory.other:
        return 'Other';
    }
  }

  String get firestoreValue {
    switch (this) {
      case OrgCalendarCategory.liturgy:
        return 'liturgy';
      case OrgCalendarCategory.academics:
        return 'academics';
      case OrgCalendarCategory.athletics:
        return 'athletics';
      case OrgCalendarCategory.ministry:
        return 'ministry';
      case OrgCalendarCategory.other:
        return 'other';
    }
  }
}

OrgCalendarCategory orgCalendarCategoryFromFirestore(String? value) {
  switch (value) {
    case 'liturgy':
      return OrgCalendarCategory.liturgy;
    case 'academics':
      return OrgCalendarCategory.academics;
    case 'athletics':
      return OrgCalendarCategory.athletics;
    case 'ministry':
      return OrgCalendarCategory.ministry;
    case 'other':
    default:
      return OrgCalendarCategory.other;
  }
}

/// Who can view an organization calendar event.
enum OrgCalendarVisibility {
  organization,
  groups,
}

extension OrgCalendarVisibilityLabels on OrgCalendarVisibility {
  String get label {
    switch (this) {
      case OrgCalendarVisibility.organization:
        return 'Entire organization';
      case OrgCalendarVisibility.groups:
        return 'Selected groups';
    }
  }

  String get firestoreValue {
    switch (this) {
      case OrgCalendarVisibility.organization:
        return 'organization';
      case OrgCalendarVisibility.groups:
        return 'groups';
    }
  }
}

OrgCalendarVisibility orgCalendarVisibilityFromFirestore(String? value) {
  switch (value) {
    case 'groups':
      return OrgCalendarVisibility.groups;
    case 'organization':
    default:
      return OrgCalendarVisibility.organization;
  }
}

/// Shared school/organization event. Never includes personal spiritual data.
class OrgCalendarEvent {
  const OrgCalendarEvent({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.category,
    required this.allDay,
    required this.startAt,
    required this.endAt,
    required this.visibility,
    required this.groupIds,
    required this.createdByUid,
    required this.createdAt,
    this.description = '',
    this.location = '',
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String title;
  final String description;
  final String location;
  final OrgCalendarCategory category;
  final bool allDay;
  final DateTime startAt;
  final DateTime endAt;
  final OrgCalendarVisibility visibility;
  final List<String> groupIds;
  final String createdByUid;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isOrganizationWide =>
      visibility == OrgCalendarVisibility.organization;

  /// Members see org-wide events, or group-targeted events they belong to.
  bool isVisibleToMember(Iterable<String> memberGroupIds) {
    if (isOrganizationWide) return true;
    final member = memberGroupIds.toSet();
    return groupIds.any(member.contains);
  }

  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final startDay = DateTime(startAt.year, startAt.month, startAt.day);
    final endDay = DateTime(endAt.year, endAt.month, endAt.day);
    var inclusiveEnd = endDay;
    if (allDay && endDay.isAfter(startDay)) {
      inclusiveEnd = endDay.subtract(const Duration(days: 1));
    }
    if (inclusiveEnd.isBefore(startDay)) {
      inclusiveEnd = startDay;
    }
    return !d.isBefore(startDay) && !d.isAfter(inclusiveEnd);
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'title': title,
      'description': description,
      'location': location,
      'category': category.firestoreValue,
      'allDay': allDay,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'visibility': visibility.firestoreValue,
      'groupIds': visibility == OrgCalendarVisibility.organization
          ? const <String>[]
          : groupIds,
      'createdByUid': createdByUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'category': category.firestoreValue,
      'allDay': allDay,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'visibility': visibility.firestoreValue,
      'groupIds': visibility == OrgCalendarVisibility.organization
          ? const <String>[]
          : groupIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory OrgCalendarEvent.fromMap(String id, Map<String, dynamic> map) {
    final rawGroups = map['groupIds'];
    return OrgCalendarEvent(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      location: map['location'] as String? ?? '',
      category: orgCalendarCategoryFromFirestore(map['category'] as String?),
      allDay: map['allDay'] as bool? ?? false,
      startAt: _readTimestamp(map['startAt']) ?? DateTime.now(),
      endAt: _readTimestamp(map['endAt']) ??
          (_readTimestamp(map['startAt']) ?? DateTime.now()),
      visibility:
          orgCalendarVisibilityFromFirestore(map['visibility'] as String?),
      groupIds: rawGroups is List
          ? rawGroups.map((e) => e.toString()).toList()
          : const [],
      createdByUid: map['createdByUid'] as String? ?? '',
      createdAt: _readTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readTimestamp(map['updatedAt']),
    );
  }

  OrgCalendarEvent copyWith({
    String? title,
    String? description,
    String? location,
    OrgCalendarCategory? category,
    bool? allDay,
    DateTime? startAt,
    DateTime? endAt,
    OrgCalendarVisibility? visibility,
    List<String>? groupIds,
  }) {
    return OrgCalendarEvent(
      id: id,
      organizationId: organizationId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      category: category ?? this.category,
      allDay: allDay ?? this.allDay,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      visibility: visibility ?? this.visibility,
      groupIds: groupIds ?? this.groupIds,
      createdByUid: createdByUid,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
