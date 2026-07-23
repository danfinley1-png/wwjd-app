// lib/models/gift_activity.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class GiftActivity {
  final String id;
  final String title;
  final String description;
  final String? linkedQuestionId;
  final String? linkedQuestionText;
  final String? linkedResponseText;
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

  GiftActivity({
    required this.id,
    required this.title,
    required this.description,
    this.linkedQuestionId,
    this.linkedQuestionText,
    this.linkedResponseText,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'linkedQuestionId': linkedQuestionId,
      'linkedQuestionText': linkedQuestionText,
      'linkedResponseText': linkedResponseText,
      'frequency': frequency,
      'specificTime': specificTime,
      'daysOfWeek': daysOfWeek,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'isCompleted': isCompleted,
      'note': note,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'hasReminder': hasReminder,
      'userId': userId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory GiftActivity.fromMap(Map<String, dynamic> map) {
    return GiftActivity(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      linkedQuestionId: map['linkedQuestionId'],
      linkedQuestionText: map['linkedQuestionText'],
      linkedResponseText: map['linkedResponseText'],
      frequency: map['frequency'] ?? 'Daily',
      specificTime: map['specificTime'],
      daysOfWeek: List<String>.from(map['daysOfWeek'] ?? []),
      dueDate: _parseTimestamp(map['dueDate']),
      isCompleted: map['isCompleted'] ?? false,
      note: map['note'],
      completedAt: _parseTimestamp(map['completedAt']),
      hasReminder: map['hasReminder'] ?? false,
      userId: map['userId'],
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']),
    );
  }

  // Helper to safely parse Timestamp or String or null
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
  }) {
    return GiftActivity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      linkedQuestionId: linkedQuestionId ?? this.linkedQuestionId,
      linkedQuestionText: linkedQuestionText ?? this.linkedQuestionText,
      linkedResponseText: linkedResponseText ?? this.linkedResponseText,
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
    );
  }
}