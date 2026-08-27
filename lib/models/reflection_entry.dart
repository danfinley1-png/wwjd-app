import 'package:cloud_firestore/cloud_firestore.dart';

/// A single dated note within a [ReflectionThread].
class ReflectionEntry {
  const ReflectionEntry({
    required this.id,
    required this.threadId,
    required this.body,
    this.createdAt,
  });

  final String id;
  final String threadId;
  final String body;
  final DateTime? createdAt;

  factory ReflectionEntry.fromMap(String id, Map<String, dynamic> map) {
    return ReflectionEntry(
      id: id,
      threadId: map['threadId']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      createdAt: _parseTimestamp(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'threadId': threadId,
      'body': body.trim(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
