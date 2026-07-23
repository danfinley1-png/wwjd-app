import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// A single message in the Seeking God's Wisdom chat / MyHistory timeline.
class ChatMessage {
  final String id;
  final DateTime timestamp;
  final bool isUser;
  final String text;
  final bool isStructuredSample;
  final bool isLoading;
  final bool isSpiritualNourishment;
  final bool isStaticPrompt;
  final bool isShared;
  final DateTime? sharedAt;

  ChatMessage({
    String? id,
    DateTime? timestamp,
    required this.isUser,
    required this.text,
    this.isStructuredSample = false,
    this.isLoading = false,
    this.isSpiritualNourishment = false,
    this.isStaticPrompt = false,
    this.isShared = false,
    this.sharedAt,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  /// Skip loading placeholders, empty stubs, and static welcome/section prompts.
  bool get isPersistable =>
      !isLoading &&
      text.isNotEmpty &&
      !isStaticPrompt &&
      !isSpiritualNourishment;

  /// True for real AI responses to user questions (shows action bar).
  bool get showsConversationActions =>
      !isUser &&
      !isLoading &&
      !isStaticPrompt &&
      !isSpiritualNourishment &&
      !isStructuredSample;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'isUser': isUser,
      'text': text,
      'isStructuredSample': isStructuredSample,
      'isLoading': isLoading,
      'isSpiritualNourishment': isSpiritualNourishment,
      'isStaticPrompt': isStaticPrompt,
      'isShared': isShared,
      'sharedAt': sharedAt?.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString(),
      timestamp: _parseTimestamp(map['timestamp']),
      isUser: map['isUser'] == true,
      text: map['text']?.toString() ?? '',
      isStructuredSample: map['isStructuredSample'] == true,
      isLoading: map['isLoading'] == true,
      isSpiritualNourishment: map['isSpiritualNourishment'] == true,
      isStaticPrompt: map['isStaticPrompt'] == true,
      isShared: map['isShared'] == true,
      sharedAt: map['sharedAt'] != null ? DateTime.tryParse(map['sharedAt'].toString()) : null,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  /// Content hash used when legacy messages lack an id.
  String contentHash() {
    return '${isUser}_${text.hashCode}';
  }
}
