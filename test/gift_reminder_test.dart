import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/gift_activity_link.dart';
import 'package:wwjd_app/core/gift_ics.dart';
import 'package:wwjd_app/core/gift_reminder_utils.dart';
import 'package:wwjd_app/models/gift_activity.dart';
GiftActivity _gift({
  String id = 'abc-123',
  String title = 'Morning Prayer',
  String frequency = 'Daily',
  String? specificTime,
  List<String> daysOfWeek = const [],
}) {
  return GiftActivity(
    id: id,
    title: title,
    description: 'Spend five quiet minutes with the Lord.',
    frequency: frequency,
    specificTime: specificTime,
    daysOfWeek: daysOfWeek,
    hasReminder: true,
  );
}

void main() {
  group('GiftReminderUtils', () {
    test('parses 24-hour and AM/PM times', () {
      expect(GiftReminderUtils.parseTime('07:00').hour, 7);
      expect(GiftReminderUtils.parseTime('7:30 AM').hour, 7);
      expect(GiftReminderUtils.parseTime('7:30 PM').hour, 19);
    });

    test('recurrence summary for daily gift', () {
      final gift = _gift(specificTime: '07:00');
      expect(
        GiftReminderUtils.recurrenceSummary(gift),
        contains('Every day at'),
      );
    });

    test('recurrence summary for weekly gift with days', () {
      final gift = _gift(
        frequency: 'Weekly',
        specificTime: '07:00',
        daysOfWeek: ['Monday', 'Wednesday'],
      );
      expect(
        GiftReminderUtils.recurrenceSummary(gift),
        contains('Weekly on Monday, Wednesday at 7:00'),
      );
    });

    test('notification body prompts opening the activity', () {
      final body = GiftReminderUtils.notificationBody(_gift());
      expect(body, contains('Tap to open in WWJD-DI'));
      expect(body, contains('Morning Prayer'));
    });
  });
  group('GiftIcs', () {
    test('builds valid calendar file with branding and recurrence', () {
      final ics = GiftIcs.build(
        _gift(specificTime: '07:00'),
        now: DateTime(2026, 7, 28, 12),
      );

      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('PRODID:-//WWJD-DI//Kingdom Challenge//EN'));
      expect(ics, contains('SUMMARY:WWJD-DI · Morning Prayer'));
      expect(ics, contains('URL:${GiftActivityLink.url('abc-123')}'));
      expect(ics, contains('Open in WWJD-DI to mark complete'));
      expect(ics, contains('RRULE:FREQ=DAILY'));
      expect(ics, contains('END:VCALENDAR'));
    });

    test('weekly ICS includes BYDAY when configured', () {      final ics = GiftIcs.build(
        _gift(
          frequency: 'Weekly',
          specificTime: '07:00',
          daysOfWeek: ['Monday'],
        ),
        now: DateTime(2026, 7, 28, 12),
      );

      expect(ics, contains('RRULE:FREQ=WEEKLY;BYDAY=MO'));
    });

    test('filename slugifies title', () {
      expect(
        GiftIcs.filenameFor(_gift(title: 'Morning Prayer!')),
        'wwjd-di-gift-morning-prayer.ics',
      );
    });
  });
}
