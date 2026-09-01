import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/admin/models/group_schedule.dart';
import 'package:wwjd_app/admin/models/service_hours.dart';
import 'package:wwjd_app/core/gift_tracking.dart';
import 'package:wwjd_app/core/gift_workspace.dart';
import 'package:wwjd_app/models/gift_activity.dart';
import 'package:wwjd_app/models/gift_status.dart';
import 'package:wwjd_app/models/group_practice_instance.dart';

GiftActivity _gift({
  String id = 'g1',
  String title = 'Test gift',
  String frequency = 'Daily',
  GiftStatus status = GiftStatus.active,
  List<String> completionDates = const [],
  DateTime? completedAt,
}) {
  return GiftActivity(
    id: id,
    title: title,
    description: 'Description',
    frequency: frequency,
    status: status,
    completionDates: completionDates,
    completedAt: completedAt,
  );
}

GroupPracticeInstance _practice({
  String id = 'p1',
  bool active = true,
  List<String> times = const ['07:00'],
  List<String> completionSlots = const [],
  GroupScheduleRecurrence recurrence = GroupScheduleRecurrence.daily,
  List<String> daysOfWeek = const [],
}) {
  return GroupPracticeInstance(
    id: id,
    groupScheduleId: 'gs1',
    organizationId: 'org1',
    groupId: 'grp1',
    title: 'Group Rosary',
    description: '',
    times: times,
    recurrence: recurrence,
    daysOfWeek: daysOfWeek,
    completionSlots: completionSlots,
    active: active,
  );
}

ServiceHourEntry _hours({
  String id = 'h1',
  required DateTime date,
  String status = ServiceHourEntry.statusLogged,
  String note = 'Packed boxes',
}) {
  return ServiceHourEntry(
    id: id,
    projectId: 'proj1',
    orgId: 'org1',
    userId: 'u1',
    date: date,
    hours: 2,
    note: note,
    status: status,
    submittedAt: date,
  );
}

void main() {
  final monday = DateTime(2026, 8, 31); // Monday
  final tuesday = DateTime(2026, 9, 1);
  final lastMonday = DateTime(2026, 8, 24);

  group('Schedule vs Active', () {
    test('recurring gift is on Schedule, never Active', () {
      final gift = _gift();
      expect(GiftWorkspace.isOnSchedule(gift, monday), isTrue);
      expect(GiftWorkspace.isActiveChallenge(gift, monday), isFalse);
    });

    test('one-time challenge without reminder is on Active, never Schedule', () {
      final gift = _gift(frequency: 'Once');
      expect(GiftWorkspace.isOnSchedule(gift, monday), isFalse);
      expect(GiftWorkspace.isActiveChallenge(gift, monday), isTrue);
    });

    test('one-time with a reminder is on Schedule, not Active', () {
      final gift = GiftActivity(
        id: 'remind',
        title: 'Pray',
        description: 'Description',
        frequency: 'Once',
        hasReminder: true,
        specificTime: '07:00',
      );
      expect(GiftWorkspace.hasScheduleCadence(gift), isTrue);
      expect(GiftWorkspace.isOnSchedule(gift, monday), isTrue);
      expect(GiftWorkspace.isActiveChallenge(gift, monday), isFalse);
    });

    test('daily gift leaves Schedule after mark-complete today', () {
      final gift = _gift(completionDates: [GiftTracking.dateKey(monday)]);
      expect(GiftWorkspace.isOnSchedule(gift, monday), isFalse);
      expect(GiftWorkspace.isActiveChallenge(gift, monday), isFalse);
      expect(GiftTracking.isDue(gift, monday), isFalse);
      expect(GiftWorkspace.giftCompletedToday(gift, monday), isTrue);
    });

    test('daily gift returns to Schedule the next day', () {
      final gift = _gift(completionDates: [GiftTracking.dateKey(monday)]);
      expect(GiftWorkspace.isOnSchedule(gift, tuesday), isTrue);
      expect(GiftTracking.isDue(gift, tuesday), isTrue);
    });

    test('completed one-time leaves Active permanently', () {
      final gift = _gift(
        frequency: 'Once',
        status: GiftStatus.completed,
        completionDates: [GiftTracking.dateKey(monday)],
        completedAt: monday,
      );
      expect(GiftWorkspace.isActiveChallenge(gift, monday), isFalse);
      expect(GiftWorkspace.isOnSchedule(gift, monday), isFalse);
      expect(GiftWorkspace.giftOnDoneTab(gift, GiftDoneRange.today, monday), isTrue);
    });

    test('paused gifts are on neither working tab', () {
      final daily = _gift(status: GiftStatus.paused);
      final once = _gift(frequency: 'Once', status: GiftStatus.paused);
      expect(GiftWorkspace.isOnSchedule(daily, monday), isFalse);
      expect(GiftWorkspace.isActiveChallenge(once, monday), isFalse);
    });
  });

  group('Due today', () {
    test('Due today excludes weekly/monthly period-due items', () {
      final daily = _gift(id: 'daily');
      final weekly = _gift(id: 'weekly', frequency: 'Weekly');
      final monthly = _gift(id: 'monthly', frequency: 'Monthly');
      final items = GiftWorkspace.scheduleGifts(
        [daily, weekly, monthly],
        monday,
        GiftScheduleFilter.dueToday,
      );
      expect(items.map((g) => g.id), ['daily']);
    });

    test('completed daily gift leaves Schedule and Due today', () {
      final due = _gift(id: 'open');
      final done = _gift(
        id: 'done',
        completionDates: [GiftTracking.dateKey(monday)],
      );
      expect(
        GiftWorkspace.scheduleGifts([due, done], monday, GiftScheduleFilter.dueToday)
            .map((g) => g.id),
        ['open'],
      );
      expect(GiftWorkspace.isOnSchedule(done, monday), isFalse);
    });

    test('group practice leaves Schedule when every today slot is done', () {
      final slot = '${GiftTracking.dateKey(monday)}@07:00';
      final practice = _practice(completionSlots: [slot]);
      expect(GiftWorkspace.isPracticeOnSchedule(practice, monday), isFalse);
      expect(
        GiftWorkspace.schedulePractices(
          [practice],
          monday,
          GiftScheduleFilter.dueToday,
        ),
        isEmpty,
      );
      expect(GiftWorkspace.practiceCompletedToday(practice, monday), isTrue);
    });

    test('weekly practice stays on All scheduled on an off day, not Due today', () {
      final practice = _practice(
        recurrence: GroupScheduleRecurrence.weekly,
        daysOfWeek: const ['Wednesday'],
      );
      expect(GiftWorkspace.isPracticeOnSchedule(practice, monday), isTrue);
      expect(GiftWorkspace.practiceDueToday(practice, monday), isFalse);
      expect(GiftWorkspace.practiceDueThisWeek(practice, monday), isTrue);
    });
  });

  group('Done ranges', () {
    test('this week includes Monday completions and excludes last week', () {
      final thisWeek = _gift(
        id: 'this',
        frequency: 'Once',
        status: GiftStatus.completed,
        completionDates: [GiftTracking.dateKey(monday)],
      );
      final lastWeek = _gift(
        id: 'last',
        frequency: 'Once',
        status: GiftStatus.completed,
        completionDates: [GiftTracking.dateKey(lastMonday)],
      );
      expect(
        GiftWorkspace.giftOnDoneTab(thisWeek, GiftDoneRange.thisWeek, monday),
        isTrue,
      );
      expect(
        GiftWorkspace.giftOnDoneTab(lastWeek, GiftDoneRange.thisWeek, monday),
        isFalse,
      );
      expect(
        GiftWorkspace.giftOnDoneTab(lastWeek, GiftDoneRange.all, monday),
        isTrue,
      );
    });

    test('semester is Fall from August through December', () {
      final window = GiftWorkspace.semesterContaining(monday);
      expect(window.start, DateTime(2026, 8, 1));
      expect(window.end, DateTime(2026, 12, 31));
    });

    test('pending hours stay off Done; logged hours appear', () {
      final pending = _hours(
        id: 'pending',
        date: monday,
        status: ServiceHourEntry.statusPending,
      );
      final logged = _hours(date: monday);
      expect(GiftWorkspace.hourOnDoneTab(pending, GiftDoneRange.today, monday), isFalse);
      expect(GiftWorkspace.hourOnDoneTab(logged, GiftDoneRange.today, monday), isTrue);
      expect(GiftWorkspace.hourCompletedToday(logged, monday), isTrue);
    });

    test('completed today rows omit still-open schedule items', () {
      final openDaily = _gift(id: 'open');
      final doneDaily = _gift(
        id: 'done',
        completionDates: [GiftTracking.dateKey(monday)],
      );
      final rows = GiftWorkspace.completedTodayRows(
        gifts: [openDaily, doneDaily],
        practices: const [],
        hours: const [],
        now: monday,
      );
      expect(rows.map((r) => r.id), ['done']);
      expect(GiftWorkspace.isOnSchedule(doneDaily, monday), isFalse);
    });
  });
}
