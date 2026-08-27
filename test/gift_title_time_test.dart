import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/gift_title_time.dart';

void main() {
  group('GiftTitleTime', () {
    test('detects titles that mention a clock time', () {
      expect(GiftTitleTime.titleReflectsTime('Morning Prayer at 7:00 AM'), isTrue);
      expect(GiftTitleTime.titleReflectsTime('Evening Examen'), isFalse);
    });

    test('replaces short AM time when schedule changes', () {
      final updated = GiftTitleTime.syncTitleWithTime(
        title: 'Morning Prayer at 7 AM',
        previousStoredTime: '07:00',
        newTime: const TimeOfDay(hour: 6, minute: 0),
      );
      expect(updated.toLowerCase(), contains('6'));
      expect(updated.toLowerCase(), isNot(contains('7 am')));
    });

    test('replaces AM/PM time when schedule changes', () {
      final updated = GiftTitleTime.syncTitleWithTime(
        title: 'Morning Prayer at 7:00 AM',
        previousStoredTime: '07:00',
        newTime: const TimeOfDay(hour: 8, minute: 30),
      );
      expect(updated, contains('8:30'));
      expect(updated, isNot(contains('7:00')));
    });

    test('leaves titles without time unchanged', () {
      const title = 'Serve at the food pantry';
      expect(
        GiftTitleTime.syncTitleWithTime(
          title: title,
          previousStoredTime: '07:00',
          newTime: const TimeOfDay(hour: 9, minute: 0),
        ),
        title,
      );
    });
  });
}
