import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/share_content.dart';

void main() {
  group('ShareContent', () {
    test('reflection confirm title', () {
      const content = ShareContent(
        kind: ShareContentKind.reflection,
        title: 'Shared Reflection',
        question: 'Should I forgive?',
        response: 'Yes, because...',
      );
      expect(content.confirmTitle, 'Share Reflection');
    });

    test('gift factory sets kingdom challenge question', () {
      final content = ShareContent.gift(
        title: 'Pray the Rosary',
        description: 'Daily decade',
      );
      expect(content.isGift, isTrue);
      expect(content.question, 'Kingdom Challenge: Pray the Rosary');
    });

    test('formatShareText includes attribution and url', () {
      const content = ShareContent(
        kind: ShareContentKind.reflection,
        title: 'Shared Reflection',
        question: 'How do I trust God?',
        response: 'Trust begins in prayer.',
      );

      final text = ShareContent.formatShareText(
        content: content,
        shareAnonymously: false,
        displayName: 'Maria',
        favoriteSaint: 'St. Joseph',
        url: 'https://example.com/s/abc',
      );

      expect(text, contains('Maria'));
      expect(text, contains('St. Joseph'));
      expect(text, contains('https://example.com/s/abc'));
    });
  });
}
