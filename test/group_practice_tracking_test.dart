import 'package:flutter_test/flutter_test.dart';

import 'package:wwjd_app/admin/models/group_schedule.dart';
import 'package:wwjd_app/core/group_practice_tracking.dart';
import 'package:wwjd_app/models/group_practice_instance.dart';

GroupPracticeInstance _practice({
  List<String> times = const ['06:00', '18:00'],
  GroupScheduleRecurrence recurrence = GroupScheduleRecurrence.daily,
  List<String> daysOfWeek = const [],
  List<String> completionSlots = const [],
}) {
  return GroupPracticeInstance(
    id: 'sched-1',
    groupScheduleId: 'sched-1',
    organizationId: 'org-1',
    groupId: 'group-1',
    title: 'Morning prayer',
    description: 'Angelus',
    times: times,
    recurrence: recurrence,
    daysOfWeek: daysOfWeek,
    completionSlots: completionSlots,
  );
}

void main() {
  group('GroupPracticeTracking', () {
    test('daily schedule applies every day', () {
      final practice = _practice();
      final monday = DateTime(2026, 7, 20); // Monday
      expect(
        GroupPracticeTracking.appliesOnDate(practice, monday),
        isTrue,
      );
      expect(GroupPracticeTracking.slotsForDate(practice, monday).length, 2);
    });

    test('weekly schedule respects days of week', () {
      final practice = _practice(
        recurrence: GroupScheduleRecurrence.weekly,
        daysOfWeek: const ['Monday', 'Wednesday'],
      );
      final monday = DateTime(2026, 7, 20);
      final tuesday = DateTime(2026, 7, 21);
      expect(GroupPracticeTracking.appliesOnDate(practice, monday), isTrue);
      expect(GroupPracticeTracking.appliesOnDate(practice, tuesday), isFalse);
    });

    test('isDueNow when a slot is incomplete', () {
      final practice = _practice();
      final monday = DateTime(2026, 7, 20, 12, 0);
      expect(GroupPracticeTracking.isDueNow(practice, monday), isTrue);
    });

    test('markNextSlotComplete records slot and streak', () {
      final practice = _practice();
      final monday = DateTime(2026, 7, 20, 7, 0);
      final afterFirst =
          GroupPracticeTracking.markNextSlotComplete(practice, monday);
      expect(afterFirst.completionSlots.length, 1);
      expect(afterFirst.totalCompletions, 1);
      expect(afterFirst.currentStreak, 0);

      final afterSecond =
          GroupPracticeTracking.markNextSlotComplete(afterFirst, monday);
      expect(afterSecond.completionSlots.length, 2);
      expect(afterSecond.currentStreak, 1);
    });

    test('dueToday filters active incomplete practices', () {
      final due = _practice();
      final done = _practice(
        completionSlots: const ['2026-07-20@06:00', '2026-07-20@18:00'],
      );
      final monday = DateTime(2026, 7, 20);
      final results = GroupPracticeTracking.dueToday([due, done], monday);
      expect(results.length, 1);
      expect(results.first.id, 'sched-1');
    });
  });
}
