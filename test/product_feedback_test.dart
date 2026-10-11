import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/services/product_feedback_service.dart';
import 'package:wwjd_app/models/pastoral_theme.dart';
import 'package:wwjd_app/models/product_feedback.dart';

void main() {
  group('ProductFeedbackService payloads', () {
    test('profile document includes uid and text, never question text', () {
      final payload = ProductFeedbackService.buildProfileDocument(
        uid: 'user-1',
        text: 'The submit button is slow on mobile.',
        type: ProductFeedbackType.bug,
        email: 'member@example.com',
        displayName: 'Pat',
        createdAt: DateTime.utc(2026, 9, 2),
      );

      expect(payload['uid'], 'user-1');
      expect(payload['text'], 'The submit button is slow on mobile.');
      expect(payload['type'], 'bug');
      expect(payload['source'], 'profile');
      expect(payload['email'], 'member@example.com');
      expect(payload['displayName'], 'Pat');
      expect(payload.keys.toSet(), ProductFeedbackService.allowedProfileKeys);
      for (final key in ProductFeedback.forbiddenSpiritualKeys) {
        expect(payload.containsKey(key), isFalse);
      }
    });

    test('rejects empty text', () {
      expect(
        () => ProductFeedbackService.buildProfileDocument(
          uid: 'user-1',
          text: '   ',
          createdAt: DateTime.utc(2026, 9, 2),
        ),
        throwsArgumentError,
      );
    });

    test('does not store email as display name', () {
      final payload = ProductFeedbackService.buildProfileDocument(
        uid: 'user-1',
        text: 'Suggestion about the sidebar.',
        email: 'member@example.com',
        displayName: 'member@example.com',
        createdAt: DateTime.utc(2026, 9, 2),
      );
      expect(payload.containsKey('displayName'), isFalse);
    });

    test('helpful vote stores only flag and theme', () {
      final payload = ProductFeedbackService.buildHelpfulDocument(
        helpful: true,
        theme: PastoralThemeCategory.prayer.firestoreValue,
        createdAt: DateTime.utc(2026, 9, 2),
      );

      expect(payload['helpful'], isTrue);
      expect(payload['theme'], 'prayer');
      expect(payload['source'], 'seeking_gods_wisdom');
      expect(payload.keys.toSet(), ProductFeedbackService.allowedHelpfulKeys);
      expect(payload.containsKey('uid'), isFalse);
      expect(payload.containsKey('text'), isFalse);
      expect(payload.containsKey('question'), isFalse);
      for (final key in ProductFeedback.forbiddenSpiritualKeys) {
        expect(payload.containsKey(key), isFalse);
      }
    });

    test('helpful vote omits unknown theme instead of storing question text', () {
      final payload = ProductFeedbackService.buildHelpfulDocument(
        helpful: false,
        theme: 'How do I pray the Rosary every day?',
        createdAt: DateTime.utc(2026, 9, 2),
      );
      expect(payload.containsKey('theme'), isFalse);
      expect(payload['helpful'], isFalse);
    });
  });

  group('ProductFeedback.fromMap', () {
    test('rejects documents that copied a question field', () {
      expect(
        () => ProductFeedback.fromMap('id', {
          'uid': 'u',
          'text': 'bug',
          'type': 'bug',
          'question': 'Should I lie?',
          'createdAt': DateTime.utc(2026, 9, 2),
        }),
        throwsFormatException,
      );
    });
  });
}
