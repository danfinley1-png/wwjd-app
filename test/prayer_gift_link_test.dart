import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/catholic_prayers/prayer_gift_link.dart';
import 'package:wwjd_app/core/prayer_link.dart';
import 'package:wwjd_app/models/gift_activity.dart';

void main() {
  group('PrayerGiftLink', () {
    test('detects Morning Angelus from title', () {
      expect(
        PrayerGiftLink.detectPrayerId(title: 'Morning Angelus at 7 AM'),
        'angelus',
      );
    });

    test('detects Memorare from title', () {
      expect(
        PrayerGiftLink.detectPrayerId(title: 'Daily Memorare'),
        'memorare',
      );
    });

    test('returns null for non-prayer gifts', () {
      expect(
        PrayerGiftLink.detectPrayerId(title: 'Call my elderly neighbor'),
        isNull,
      );
    });

    test('enrich stores linkedPrayerId on gift', () {
      final gift = GiftActivity(
        id: '1',
        title: 'Pray the Angelus',
        description: 'At noon each day.',
        frequency: 'Daily',
      );
      final enriched = PrayerGiftLink.enrich(gift);
      expect(enriched.linkedPrayerId, 'angelus');
    });

    test('preserves explicit linkedPrayerId when title does not match', () {
      final gift = GiftActivity(
        id: '1',
        title: 'Evening reflection',
        description: 'Quiet time before bed.',
        frequency: 'Daily',
        linkedPrayerId: 'memorare',
      );
      final enriched = PrayerGiftLink.enrich(gift);
      expect(enriched.linkedPrayerId, 'memorare');
      expect(PrayerGiftLink.resolvePrayerId(gift), 'memorare');
    });

    test('calendar line includes stable prayer URL', () {
      final gift = GiftActivity(
        id: '1',
        title: 'Hail Mary',
        description: 'Three times daily.',
        frequency: 'Daily',
        linkedPrayerId: 'hail_mary',
      );
      final line = PrayerGiftLink.calendarLineForGift(gift);
      expect(line, contains('Hail Mary'));
      expect(line, contains(PrayerLink.url('hail_mary')));
    });

    test('parses prayer id from prayer URL', () {
      expect(
        PrayerGiftLink.prayerIdFromUrl(PrayerLink.url('memorare')),
        'memorare',
      );
    });
  });
}
