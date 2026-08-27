import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/gift_tracking.dart';
import 'package:wwjd_app/models/gift_activity.dart';
import 'package:wwjd_app/models/gift_status.dart';

GiftActivity _gift({
  String id = 'g1',
  String frequency = 'Daily',
  GiftStatus status = GiftStatus.active,
  List<String> completionDates = const [],
  List<String> daysOfWeek = const [],
  DateTime? dueDate,
  int totalCompletions = 0,
}) {
  return GiftActivity(
    id: id,
    title: 'Test gift',
    description: 'Description',
    frequency: frequency,
    status: status,
    completionDates: completionDates,
    daysOfWeek: daysOfWeek,
    dueDate: dueDate,
    totalCompletions: totalCompletions,
  );
}

void main() {
  final monday = DateTime(2026, 7, 27); // Monday
  final tuesday = DateTime(2026, 7, 28);
  final wednesday = DateTime(2026, 7, 29);
  final nextMonday = DateTime(2026, 8, 3);
  final firstOfMonth = DateTime(2026, 7, 1);
  final midMonth = DateTime(2026, 7, 15);
  final nextMonth = DateTime(2026, 8, 1);

  group('isDue', () {
    test('daily active gift is due when not completed today', () {
      expect(GiftTracking.isDue(_gift(), monday), isTrue);
    });

    test('daily gift is not due after completed today', () {
      final gift = _gift(
        completionDates: [GiftTracking.dateKey(monday)],
      );
      expect(GiftTracking.isDue(gift, monday), isFalse);
    });

    test('paused gift is never due', () {
      expect(
        GiftTracking.isDue(
          _gift(status: GiftStatus.paused),
          monday,
        ),
        isFalse,
      );
    });

    test('weekly gift due on configured weekday only', () {
      final gift = _gift(frequency: 'Weekly', daysOfWeek: ['Monday']);
      expect(GiftTracking.isDue(gift, monday), isTrue);
      expect(GiftTracking.isDue(gift, tuesday), isFalse);
    });

    test('weekly gift without weekday is due all week until completed', () {
      final gift = _gift(frequency: 'Weekly');
      expect(GiftTracking.isDue(gift, monday), isTrue);
      expect(GiftTracking.isDue(gift, tuesday), isTrue);

      final completedMonday = gift.copyWith(
        completionDates: [GiftTracking.dateKey(monday)],
      );
      expect(GiftTracking.isDue(completedMonday, tuesday), isFalse);
      expect(GiftTracking.isDue(completedMonday, nextMonday), isTrue);
    });

    test('monthly gift is due all month until completed', () {
      final gift = _gift(frequency: 'Monthly');
      expect(GiftTracking.isDue(gift, firstOfMonth), isTrue);
      expect(GiftTracking.isDue(gift, midMonth), isTrue);

      final completedEarly = gift.copyWith(
        completionDates: [GiftTracking.dateKey(firstOfMonth)],
      );
      expect(GiftTracking.isDue(completedEarly, midMonth), isFalse);
      expect(GiftTracking.isDue(completedEarly, nextMonth), isTrue);
    });

    test('one-time gift due until completed', () {
      final active = _gift(frequency: 'One-time');
      expect(GiftTracking.isDue(active, monday), isTrue);

      final done = GiftTracking.applyCompletion(active, completedAt: monday);
      expect(GiftTracking.isDue(done, tuesday), isFalse);
      expect(done.status, GiftStatus.completed);
    });
  });

  group('dueStatusLabel', () {
    test('uses period-appropriate labels', () {
      expect(
        GiftTracking.dueStatusLabel(_gift(frequency: 'Daily'), monday),
        'Due today',
      );
      expect(
        GiftTracking.dueStatusLabel(_gift(frequency: 'Weekly'), monday),
        'Due this week',
      );
      expect(
        GiftTracking.dueStatusLabel(_gift(frequency: 'Monthly'), monday),
        'Due this month',
      );
      expect(
        GiftTracking.dueStatusLabel(
          _gift(
            frequency: 'Weekly',
            completionDates: [GiftTracking.dateKey(monday)],
          ),
          monday,
        ),
        'Completed this week',
      );
    });
  });

  group('calculateStreak', () {
    test('returns 0 with no completions', () {
      expect(GiftTracking.calculateStreak([], now: wednesday), 0);
    });

    test('counts consecutive days ending today', () {
      final dates = [
        GiftTracking.dateKey(monday),
        GiftTracking.dateKey(tuesday),
        GiftTracking.dateKey(wednesday),
      ];
      expect(GiftTracking.calculateStreak(dates, now: wednesday), 3);
    });

    test('counts streak ending yesterday when not done today', () {
      final dates = [
        GiftTracking.dateKey(monday),
        GiftTracking.dateKey(tuesday),
      ];
      expect(GiftTracking.calculateStreak(dates, now: wednesday), 2);
    });

    test('breaks streak after a missed day', () {
      final dates = [
        GiftTracking.dateKey(monday),
        GiftTracking.dateKey(wednesday),
      ];
      expect(GiftTracking.calculateStreak(dates, now: wednesday), 1);
    });
  });

  group('applyCompletion', () {
    test('adds completion date and increments totals', () {
      final updated = GiftTracking.applyCompletion(_gift(), completedAt: monday);
      expect(updated.completionDates, [GiftTracking.dateKey(monday)]);
      expect(updated.totalCompletions, 1);
      expect(updated.currentStreak, 1);
      expect(updated.status, GiftStatus.active);
    });

    test('does not duplicate same-day completion', () {
      final once = GiftTracking.applyCompletion(_gift(), completedAt: monday);
      final twice = GiftTracking.applyCompletion(once, completedAt: monday);
      expect(twice.completionDates.length, 1);
      expect(twice.totalCompletions, 1);
    });
  });

  group('aggregateStats', () {
    test('summarizes due and completed counts for today', () {
      final gifts = [
        _gift(id: 'a'),
        _gift(
          id: 'b',
          completionDates: [GiftTracking.dateKey(monday)],
          totalCompletions: 1,
        ),
        _gift(id: 'c', status: GiftStatus.completed, frequency: 'One-time'),
      ];

      final stats = GiftTracking.aggregateStats(gifts, monday);
      expect(stats.dueTodayCount, 2);
      expect(stats.completedTodayCount, 1);
      expect(stats.totalCompletions, 1);
    });
  });
}
