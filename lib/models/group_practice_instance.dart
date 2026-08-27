import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin/models/group_schedule.dart';

/// A member's synced copy of a group schedule — shown in Sharing My Gifts.
class GroupPracticeInstance {
  const GroupPracticeInstance({
    required this.id,
    required this.groupScheduleId,
    required this.organizationId,
    required this.groupId,
    required this.title,
    required this.description,
    required this.times,
    required this.recurrence,
    this.groupName,
    this.organizationName,
    this.practiceText,
    this.practiceLink,
    this.daysOfWeek = const [],
    this.completionSlots = const [],
    this.lastCompleted,
    this.totalCompletions = 0,
    this.currentStreak = 0,
    this.syncedAt,
    this.active = true,
  });

  final String id;
  final String groupScheduleId;
  final String organizationId;
  final String groupId;
  final String? groupName;
  final String? organizationName;
  final String title;
  final String description;
  final String? practiceText;
  final String? practiceLink;
  final List<String> times;
  final GroupScheduleRecurrence recurrence;
  final List<String> daysOfWeek;
  final List<String> completionSlots;
  final DateTime? lastCompleted;
  final int totalCompletions;
  final int currentStreak;
  final DateTime? syncedAt;
  final bool active;

  Map<String, dynamic> toMap() {
    return {
      'groupScheduleId': groupScheduleId,
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
      'completionSlots': completionSlots,
      if (lastCompleted != null)
        'lastCompleted': Timestamp.fromDate(lastCompleted!),
      'totalCompletions': totalCompletions,
      'currentStreak': currentStreak,
      'syncedAt': FieldValue.serverTimestamp(),
      'active': active,
      'source': 'groupSchedule',
    };
  }

  factory GroupPracticeInstance.fromMap(String id, Map<String, dynamic> map) {
    return GroupPracticeInstance(
      id: id,
      groupScheduleId: map['groupScheduleId'] as String? ?? id,
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
      completionSlots: (map['completionSlots'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      lastCompleted: _readTimestamp(map['lastCompleted']),
      totalCompletions: map['totalCompletions'] as int? ?? 0,
      currentStreak: map['currentStreak'] as int? ?? 0,
      syncedAt: _readTimestamp(map['syncedAt']),
      active: map['active'] as bool? ?? true,
    );
  }

  GroupPracticeInstance copyWith({
    List<String>? completionSlots,
    DateTime? lastCompleted,
    int? totalCompletions,
    int? currentStreak,
    bool? active,
  }) {
    return GroupPracticeInstance(
      id: id,
      groupScheduleId: groupScheduleId,
      organizationId: organizationId,
      groupId: groupId,
      groupName: groupName,
      organizationName: organizationName,
      title: title,
      description: description,
      practiceText: practiceText,
      practiceLink: practiceLink,
      times: times,
      recurrence: recurrence,
      daysOfWeek: daysOfWeek,
      completionSlots: completionSlots ?? this.completionSlots,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      currentStreak: currentStreak ?? this.currentStreak,
      syncedAt: syncedAt,
      active: active ?? this.active,
    );
  }

  factory GroupPracticeInstance.fromSchedule(GroupSchedule schedule) {
    return GroupPracticeInstance(
      id: schedule.id,
      groupScheduleId: schedule.id,
      organizationId: schedule.organizationId,
      groupId: schedule.groupId,
      groupName: schedule.groupName,
      organizationName: schedule.organizationName,
      title: schedule.title,
      description: schedule.description,
      practiceText: schedule.practiceText,
      practiceLink: schedule.practiceLink,
      times: schedule.times,
      recurrence: schedule.recurrence,
      daysOfWeek: schedule.daysOfWeek,
    );
  }
}

DateTime? _readTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
