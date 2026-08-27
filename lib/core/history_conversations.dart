import '../models/chat_message.dart';

/// Groups persistable chat messages into My History conversation cards.
List<Map<String, dynamic>> parseHistoryConversations(List<ChatMessage> messages) {
  final conversations = <Map<String, dynamic>>[];
  var currentQuestion = '';
  var currentResponses = <String>[];
  DateTime? currentCreatedAt;

  for (final m in messages) {
    if (!m.isPersistable) continue;

    final text = m.text.trim();
    if (text.isEmpty) continue;

    if (m.isUser) {
      if (currentQuestion.isNotEmpty) {
        conversations.add({
          'question': currentQuestion,
          'responses': List<String>.from(currentResponses),
          'createdAt': currentCreatedAt ?? DateTime.now(),
        });
      }
      currentQuestion = text;
      currentResponses = [];
      currentCreatedAt = m.timestamp;
    } else if (currentQuestion.isNotEmpty) {
      currentResponses.add(text);
    }
  }

  if (currentQuestion.isNotEmpty) {
    conversations.add({
      'question': currentQuestion,
      'responses': List<String>.from(currentResponses),
      'createdAt': currentCreatedAt ?? DateTime.now(),
    });
  }

  conversations.sort(
    (a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime),
  );

  return conversations;
}
