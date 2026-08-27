import 'package:cloud_firestore/cloud_firestore.dart';

/// Recurrence for a group-level shared spiritual practice.
enum GroupScheduleRecurrence {
  daily,
  weekly,
}

extension GroupScheduleRecurrenceFirestore on GroupScheduleRecurrence {
  String get firestoreValue {
    switch (this) {
      case GroupScheduleRecurrence.daily:
        return 'daily';
      case GroupScheduleRecurrence.weekly:
        return 'weekly';
    }
  }
}

GroupScheduleRecurrence groupScheduleRecurrenceFromFirestore(String? value) {
  switch (value) {
    case 'weekly':
      return GroupScheduleRecurrence.weekly;
    case 'daily':
    default:
      return GroupScheduleRecurrence.daily;
  }
}

/// Organization-defined recurring practice for an accepted group.
class GroupSchedule {
  const GroupSchedule({
    required this.id,
    required this.organizationId,
    required this.groupId,
    required this.title,
    required this.description,
    required this.times,
    required this.recurrence,
    required this.createdByUid,
    required this.createdAt,
    this.groupName,
    this.organizationName,
    this.practiceText,
    this.practiceLink,
    this.daysOfWeek = const [],
    this.active = true,
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String groupId;
  final String? groupName;
  final String? organizationName;
  final String title;
  final String description;
  final String? practiceText;
  final String? practiceLink;
  /// Daily times in 24h `HH:mm` format, e.g. `06:00`, `12:00`, `18:00`.
  final List<String> times;
  final GroupScheduleRecurrence recurrence;
  final List<String> daysOfWeek;
  final String createdByUid;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool active;

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'groupId': groupId,
      if (groupName != null) 'groupName': groupName,
      if (organizationName != null) 'organizationName': organizationName,
      'title': title,
      'description': description,
      if (practiceText != null && practiceText!.trim().isNotEmpty)
        'practiceText': practiceText!.trim(),
      if (practiceLink != null && practiceLink!.trim().isNotEmpty)
        'practiceLink': practiceLink!.trim(),
      'times': times,
      'recurrence': recurrence.firestoreValue,
      'daysOfWeek': daysOfWeek,
      'createdByUid': createdByUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'active': active,
    };
  }

  factory GroupSchedule.fromMap(String id, Map<String, dynamic> map) {
    return GroupSchedule(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      groupName: map['groupName'] as String?,
      organizationName: map['organizationName'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      practiceText: map['practiceText'] as String?,
      practiceLink: map['practiceLink'] as String?,
      times: (map['times'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      recurrence: groupScheduleRecurrenceFromFirestore(
        map['recurrence'] as String?,
      ),
      daysOfWeek: (map['daysOfWeek'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      createdByUid: map['createdByUid'] as String? ?? '',
      createdAt: _readTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _readTimestamp(map['updatedAt']),
      active: map['active'] as bool? ?? true,
    );
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
