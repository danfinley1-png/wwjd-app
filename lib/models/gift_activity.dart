// lib/models/gift_activity.dart
import 'package:uuid/uuid.dart';  // If not already imported

class GiftActivity {
  final String id;
  final String title;
  final String description;
  final String? linkedQuestionId;        // Links back to WWJD response
  final String frequency;                // "Daily", "Weekly", "One-time", etc.
  final String? specificTime;            // e.g., "07:00"
  final List<String> daysOfWeek;         // For weekly recurrence
  final DateTime? dueDate;
  final bool isCompleted;
  final String? note;                    // 1-paragraph optional note
  final DateTime? completedAt;
  final bool hasReminder;
  final String? userId;                  // Ready for future login

  GiftActivity({
    required this.id,
    required this.title,
    required this.description,
    this.linkedQuestionId,
    required this.frequency,
    this.specificTime,
    this.daysOfWeek = const [],
    this.dueDate,
    this.isCompleted = false,
    this.note,
    this.completedAt,
    this.hasReminder = false,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'linkedQuestionId': linkedQuestionId,
        'frequency': frequency,
        'specificTime': specificTime,
        'daysOfWeek': daysOfWeek,
        'dueDate': dueDate?.toIso8601String(),
        'isCompleted': isCompleted,
        'note': note,
        'completedAt': completedAt?.toIso8601String(),
        'hasReminder': hasReminder,
        'userId': userId,
      };

  factory GiftActivity.fromJson(Map<String, dynamic> json) => GiftActivity(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        linkedQuestionId: json['linkedQuestionId'],
        frequency: json['frequency'],
        specificTime: json['specificTime'],
        daysOfWeek: List<String>.from(json['daysOfWeek'] ?? []),
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        isCompleted: json['isCompleted'] ?? false,
        note: json['note'],
        completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
        hasReminder: json['hasReminder'] ?? false,
        userId: json['userId'],
      );
}

// Global list for MVP (replace with proper storage later)
List<GiftActivity> globalGiftActivities = [];