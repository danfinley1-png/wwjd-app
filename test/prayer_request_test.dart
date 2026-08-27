import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/catholic_prayers/prayer_request_detector.dart';
import 'package:wwjd_app/core/catholic_prayers/prayer_response_builder.dart';

void main() {
  group('PrayerRequestDetector', () {
    test('detects direct memorare request', () {
      final match = PrayerRequestDetector.detect('Please give me the Memorare');
      expect(match, isNotNull);
      expect(match!.prayer.id, 'memorare');
    });

    test('detects standalone hail mary', () {
      final match = PrayerRequestDetector.detect('Hail Mary');
      expect(match, isNotNull);
      expect(match!.prayer.id, 'hail_mary');
    });

    test('does not hijack discernment questions mentioning prayer', () {
      final match = PrayerRequestDetector.detect(
        'Should I pray the Memorare every day when I am struggling with anxiety about my marriage?',
      );
      expect(match, isNull);
    });

    test('does not hijack long life questions', () {
      final match = PrayerRequestDetector.detect(
        'My friend is angry at me and I want to know what would Jesus do about forgiveness and whether I should pray the Our Father with him.',
      );
      expect(match, isNull);
    });
  });

  group('PrayerResponseBuilder', () {
    test('includes prayer text and suggestedActions json', () {
      final match = PrayerRequestDetector.detect('Angelus')!;
      final response = PrayerResponseBuilder.build(match);

      expect(response, contains('**Angelus**'));
      expect(response, contains('The Angel of the Lord declared unto Mary'));
      expect(response, contains('```json'));
      expect(response, contains('"suggestedActions"'));
      expect(response, isNot(contains('Two Great Commandments')));
    });
  });
}
