import 'package:cloud_firestore/cloud_firestore.dart';

/// A shareable WWJD reflection stored at `shares/{id}` for deep links.
class SharedReflection {
  final String id;
  final String question;
  final String response;
  final String title;
  final String? createdByUid;
  final DateTime? createdAt;

  const SharedReflection({
    required this.id,
    required this.question,
    required this.response,
    required this.title,
    this.createdByUid,
    this.createdAt,
  });

  factory SharedReflection.fromMap(String id, Map<String, dynamic> map) {
    return SharedReflection(
      id: id,
      question: map['question']?.toString() ?? '',
      response: map['response']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Shared Reflection',
      createdByUid: map['createdByUid']?.toString(),
      createdAt: _parseTimestamp(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'response': response,
      'title': title,
      'createdByUid': createdByUid,
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
