import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/models/gift_activity.dart';

void main() {
  group('GiftActivity sharing', () {
    test('shareBody uses description not linked WWJD response', () {
      final gift = GiftActivity(
        id: 'g1',
        title: 'Pray the Rosary',
        description: 'Pray one decade each morning before work.',
        linkedQuestionText: 'Should I skip Mass to work overtime?',
        linkedResponseText: 'Long WWJD answer about Sabbath rest...',
        frequency: 'Daily',
        userId: 'u1',
      );

      expect(gift.shareQuestion, 'Activity: Pray the Rosary');
      expect(gift.shareBody, contains('Pray one decade'));
      expect(gift.shareBody, isNot(contains('Sabbath rest')));
    });

    test('hasOriginalGuidance when linked conversation exists', () {
      final withGuidance = GiftActivity(
        id: 'g1',
        title: 'Pray the Rosary',
        description: 'Daily rosary',
        linkedQuestionText: 'Question?',
        frequency: 'Daily',
        userId: 'u1',
      );
      final manual = GiftActivity(
        id: 'g2',
        title: 'Serve at soup kitchen',
        description: 'Monthly volunteering',
        frequency: 'Monthly',
        userId: 'u1',
      );

      expect(withGuidance.hasOriginalGuidance, isTrue);
      expect(manual.hasOriginalGuidance, isFalse);
    });
  });
}
