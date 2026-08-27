import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/gift_share_payload.dart';

void main() {
  group('GiftSharePayload', () {
    test('anonymous share text includes branding', () {
      const payload = GiftSharePayload(
        title: 'Pray the Rosary',
        description: 'Pray one decade each morning.',
        personalNote: 'This has helped me stay centered.',
        shareAnonymously: true,
      );

      expect(payload.formatShareText(url: 'https://example.com/s/abc'), contains('WWJD-DI'));
      expect(payload.formatShareText(url: 'https://example.com/s/abc'), contains('Shared anonymously'));
      expect(payload.formatShareText(url: 'https://example.com/s/abc'), contains('Pray the Rosary'));
    });

    test('attributed share includes display name and saint', () {
      const payload = GiftSharePayload(
        title: 'Serve at soup kitchen',
        description: 'Volunteer monthly.',
        shareAnonymously: false,
        displayName: 'Maria',
        favoriteSaint: 'St. Teresa of Calcutta',
      );

      expect(payload.attributionLine, contains('Maria'));
      expect(payload.attributionLine, contains('St. Teresa of Calcutta'));
    });

    test('toWalkTogetherFields preserves privacy flags', () {
      const payload = GiftSharePayload(
        title: 'Daily Examen',
        description: 'Five minutes each evening.',
        linkedActivityId: 'gift-1',
        shareAnonymously: true,
      );

      final fields = payload.toWalkTogetherFields();
      expect(fields['shareType'], 'gift');
      expect(fields['linkedActivityId'], 'gift-1');
      expect(fields['shareAnonymously'], isTrue);
      expect(fields['sharedByDisplayName'], isNull);
    });
  });
}
