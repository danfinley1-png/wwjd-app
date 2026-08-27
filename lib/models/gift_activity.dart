// lib/models/gift_activity.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'gift_status.dart';

/// Distinguishes personal Gifts from group-owned copies in My Gifts.
abstract class GiftActivitySource {
  static const personal = 'personal';
  static const groupGift = 'groupGift';
}

class GiftActivity {
  final String id;
  final String title;
  final String description;
  final String? linkedQuestionId;
  final String? linkedQuestionText;
  final String? linkedResponseText;
  final String? linkedPrayerId;
  final String frequency;
  final String? specificTime;
  final List<String> daysOfWeek;
  final DateTime? dueDate;
  final bool isCompleted;
  final String? note;
  final DateTime? completedAt;
  final bool hasReminder;
  final String? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final GiftStatus status;
  final List<String> completionDates;
  final DateTime? lastCompleted;
  final int totalCompletions;
  final int currentStreak;
  /// `personal` (default) or `groupGift`.
  final String source;
  final String? groupGiftId;
  final String? groupId;
  final String? groupName;
  final String? organizationId;
  final String? organizationName;
  final String? groupLogoUrl;

  GiftActivity({
    required this.id,
    required this.title,
    required this.description,
    this.linkedQuestionId,
    this.linkedQuestionText,
    this.linkedResponseText,
    this.linkedPrayerId,
    required this.frequency,
    this.specificTime,
    this.daysOfWeek = const [],
    this.dueDate,
    this.isCompleted = false,
    this.note,
    this.completedAt,
    this.hasReminder = false,
    this.userId,
    this.createdAt,
    this.updatedAt,
    this.status = GiftStatus.active,
    this.completionDates = const [],
    this.lastCompleted,
    this.totalCompletions = 0,
    this.currentStreak = 0,
    this.source = GiftActivitySource.personal,
    this.groupGiftId,
    this.groupId,
    this.groupName,
    this.organizationId,
    this.organizationName,
    this.groupLogoUrl,
  });

  /// Optional link back to the chat conversation that suggested this gift.
  String? get sourceConversationId => linkedQuestionId;

  bool get isActive => status == GiftStatus.active;

  bool get isGroupGift => source == GiftActivitySource.groupGift;

  bool get isPersonal => !isGroupGift;

  /// Members may complete and note a group Gift, but not change its definition.
  bool get definitionLocked => isGroupGift;

  String get brandLabel {
    final group = groupName?.trim();
    if (group != null && group.isNotEmpty) return group;
    final org = organizationName?.trim();
    if (org != null && org.isNotEmpty) return org;
    return 'Group';
  }

  /// Whether this gift was created from a WWJD conversation.
  bool get hasOriginalGuidance {
    final q = linkedQuestionText?.trim();
    final r = linkedResponseText?.trim();
    return (q != null && q.isNotEmpty) || (r != null && r.isNotEmpty);
  }

  /// Question line when sharing this gift (not the original moral dilemma).
  String get shareQuestion => 'Activity: $title';

  /// Body when sharing this gift — description and personal note only.
  String get shareBody {
    final parts = <String>[description.trim()];
    final personalNote = note?.trim();
    if (personalNote != null && personalNote.isNotEmpty) {
      parts.add('**My note:** $personalNote');
    }
    return parts.join('\n\n');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'linkedQuestionId': linkedQuestionId,
      'sourceConversationId': linkedQuestionId,
      'linkedQuestionText': linkedQuestionText,
      'linkedResponseText': linkedResponseText,
      if (linkedPrayerId != null && linkedPrayerId!.trim().isNotEmpty)
        'linkedPrayerId': linkedPrayerId!.trim(),
      'frequency': frequency,
      'specificTime': specificTime,
      'daysOfWeek': daysOfWeek,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'isCompleted': isCompleted || status == GiftStatus.completed,
      'note': note,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'hasReminder': hasReminder,
      'userId': userId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': status.firestoreValue,
      'completionDates': completionDates,
      'lastCompleted':
          lastCompleted != null ? Timestamp.fromDate(lastCompleted!) : null,
      'totalCompletions': totalCompletions,
      'currentStreak': currentStreak,
      'source': isGroupGift
          ? GiftActivitySource.groupGift
          : GiftActivitySource.personal,
      if (groupGiftId != null && groupGiftId!.isNotEmpty)
        'groupGiftId': groupGiftId,
      if (groupId != null && groupId!.isNotEmpty) 'groupId': groupId,
      if (groupName != null && groupName!.isNotEmpty) 'groupName': groupName,
      if (organizationId != null && organizationId!.isNotEmpty)
        'organizationId': organizationId,
      if (organizationName != null && organizationName!.isNotEmpty)
        'organizationName': organizationName,
      if (groupLogoUrl != null && groupLogoUrl!.isNotEmpty)
        'groupLogoUrl': groupLogoUrl,
    };
  }

  factory GiftActivity.fromMap(Map<String, dynamic> map) {
    final legacyCompleted = map['isCompleted'] ?? false;
    final frequency = map['frequency']?.toString() ?? 'Daily';
    var status = GiftStatus.fromFirestore(map['status']?.toString());

    if (map['status'] == null && legacyCompleted) {
      status = GiftStatus.completed;
    }

    final sourceId = map['sourceConversationId'] ?? map['linkedQuestionId'];

    var completionDates = _parseCompletionDates(map['completionDates']);
    final completedAt = _parseTimestamp(map['completedAt']);
    final lastCompleted =
        _parseTimestamp(map['lastCompleted']) ?? completedAt;

    if (completionDates.isEmpty && completedAt != null) {
      completionDates = [_dateKeyFromDateTime(completedAt)];
    }

    var totalCompletions = map['totalCompletions'] as int? ?? completionDates.length;
    var currentStreak = map['currentStreak'] as int? ?? 0;

    return GiftActivity(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      linkedQuestionId: sourceId,
      linkedQuestionText: map['linkedQuestionText'],
      linkedResponseText: map['linkedResponseText'],
      linkedPrayerId: map['linkedPrayerId']?.toString(),
      frequency: frequency,
      specificTime: map['specificTime'],
      daysOfWeek: List<String>.from(map['daysOfWeek'] ?? []),
      dueDate: _parseTimestamp(map['dueDate']),
      isCompleted: legacyCompleted || status == GiftStatus.completed,
      note: map['note'],
      completedAt: completedAt,
      hasReminder: map['hasReminder'] ?? false,
      userId: map['userId'],
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']),
      status: status,
      completionDates: completionDates,
      lastCompleted: lastCompleted,
      totalCompletions: totalCompletions,
      currentStreak: currentStreak,
      source: map['source']?.toString() == GiftActivitySource.groupGift
          ? GiftActivitySource.groupGift
          : GiftActivitySource.personal,
      groupGiftId: map['groupGiftId']?.toString(),
      groupId: map['groupId']?.toString(),
      groupName: map['groupName']?.toString(),
      organizationId: map['organizationId']?.toString(),
      organizationName: map['organizationName']?.toString(),
      groupLogoUrl: map['groupLogoUrl']?.toString(),
    );
  }

  static List<String> _parseCompletionDates(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static String _dateKeyFromDateTime(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  GiftActivity copyWith({
    String? id,
    String? title,
    String? description,
    String? linkedQuestionId,
    String? linkedQuestionText,
    String? linkedResponseText,
    String? linkedPrayerId,
    String? frequency,
    String? specificTime,
    List<String>? daysOfWeek,
    DateTime? dueDate,
    bool? isCompleted,
    String? note,
    DateTime? completedAt,
    bool? hasReminder,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    GiftStatus? status,
    List<String>? completionDates,
    DateTime? lastCompleted,
    int? totalCompletions,
    int? currentStreak,
    String? source,
    String? groupGiftId,
    String? groupId,
    String? groupName,
    String? organizationId,
    String? organizationName,
    String? groupLogoUrl,
  }) {
    return GiftActivity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      linkedQuestionId: linkedQuestionId ?? this.linkedQuestionId,
      linkedQuestionText: linkedQuestionText ?? this.linkedQuestionText,
      linkedResponseText: linkedResponseText ?? this.linkedResponseText,
      linkedPrayerId: linkedPrayerId ?? this.linkedPrayerId,
      frequency: frequency ?? this.frequency,
      specificTime: specificTime ?? this.specificTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      note: note ?? this.note,
      completedAt: completedAt ?? this.completedAt,
      hasReminder: hasReminder ?? this.hasReminder,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      completionDates: completionDates ?? this.completionDates,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      currentStreak: currentStreak ?? this.currentStreak,
      source: source ?? this.source,
      groupGiftId: groupGiftId ?? this.groupGiftId,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      groupLogoUrl: groupLogoUrl ?? this.groupLogoUrl,
    );
  }
}
