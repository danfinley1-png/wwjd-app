import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/history_conversations.dart';
import 'package:wwjd_app/models/chat_message.dart';

void main() {
  group('parseHistoryConversations', () {
    test('includes responses that contain NON-NEGOTIABLE', () {
      final messages = [
        ChatMessage(isUser: true, text: 'How should I forgive?'),
        ChatMessage(
          isUser: false,
          text: 'Forgiveness is central.\n\n**Kingdom Challenge (NON-NEGOTIABLE):** Pray daily.',
        ),
      ];

      final conversations = parseHistoryConversations(messages);

      expect(conversations.length, 1);
      expect(conversations.first['question'], 'How should I forgive?');
      expect(conversations.first['responses'], hasLength(1));
    });

    test('skips non-persistable static prompts', () {
      final messages = [
        ChatMessage(isUser: false, text: 'Welcome', isStaticPrompt: true),
        ChatMessage(isUser: true, text: 'Real question'),
        ChatMessage(isUser: false, text: 'Real answer'),
      ];

      final conversations = parseHistoryConversations(messages);

      expect(conversations.length, 1);
      expect(conversations.first['question'], 'Real question');
    });
  });
}
