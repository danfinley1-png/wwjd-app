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

  /// Parsed suggestedActions from the API (JSON stripped from [text] for display).
  final List<Map<String, String>>? suggestedActions;

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
    this.suggestedActions,
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
      if (suggestedActions != null && suggestedActions!.isNotEmpty)
        'suggestedActions': suggestedActions,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString(),
      timestamp: _parseTimestamp(map['timestamp']),
      isUser: _parseIsUser(map),
      text: map['text']?.toString() ?? '',
      isStructuredSample: map['isStructuredSample'] == true,
      isLoading: map['isLoading'] == true,
      isSpiritualNourishment: map['isSpiritualNourishment'] == true,
      isStaticPrompt: map['isStaticPrompt'] == true,
      isShared: map['isShared'] == true,
      sharedAt: map['sharedAt'] != null ? DateTime.tryParse(map['sharedAt'].toString()) : null,
      suggestedActions: _parseSuggestedActions(map['suggestedActions']),
    );
  }

  static List<Map<String, String>>? _parseSuggestedActions(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    final parsed = <Map<String, String>>[];
    for (final item in value) {
      if (item is! Map) continue;
      parsed.add(
        item.map((key, val) => MapEntry(key.toString(), val?.toString() ?? '')),
      );
    }
    return parsed.isEmpty ? null : parsed;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  static bool _parseIsUser(Map<String, dynamic> map) {
    final role = map['role']?.toString().toLowerCase();
    if (role == 'user') return true;
    if (role == 'assistant' || role == 'model') return false;

    final value = map['isUser'];
    if (value == true) return true;
    if (value == false) return false;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return false;
  }

  /// Content hash used when legacy messages lack an id.
  String contentHash() {
    return '${isUser}_${text.hashCode}';
  }
}
