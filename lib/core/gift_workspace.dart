import '../admin/models/group_schedule.dart';
import '../admin/models/service_hours.dart';
import '../models/gift_activity.dart';
import '../models/gift_status.dart';
import '../models/group_practice_instance.dart';
import 'gift_tracking.dart';
import 'group_practice_tracking.dart';

/// Date window for the Done tab (and Completed today uses [today]).
enum GiftDoneRange { today, thisWeek, thisSemester, all }

/// Schedule tab chips. Default is [dueToday].
enum GiftScheduleFilter { dueToday, thisWeek, allScheduled }

/// Classification for Sharing My Gifts tabs. One working tab per item.
class GiftWorkspace {
  GiftWorkspace._();

  /// Recurring gifts, or one-time gifts with a reminder, still in progress.
  static bool isOnSchedule(GiftActivity gift, [DateTime? now]) {
    if (gift.status != GiftStatus.active) return false;
    if (!hasScheduleCadence(gift)) return false;
    if (GiftTracking.isCompletedInPeriod(gift, now)) return false;
    return true;
  }

  /// Recurring frequency, or a reminder/time — not an unscheduled one-time.
  static bool hasScheduleCadence(GiftActivity gift) {
    if (!GiftTracking.isOneTime(gift)) return true;
    if (gift.hasReminder) return true;
    final time = gift.specificTime?.trim() ?? '';
    return time.isNotEmpty;
  }

  /// Group practices that still belong on Schedule (not finished for today).
  static bool isPracticeOnSchedule(
    GroupPracticeInstance practice, [
    DateTime? now,
  ]) {
    if (!practice.active) return false;
    final today = now ?? DateTime.now();
    if (!GroupPracticeTracking.appliesOnDate(practice, today)) return true;
    final slots = GroupPracticeTracking.slotsForDate(practice, today);
    if (slots.isEmpty) return true;
    return slots.any((slot) => !practice.completionSlots.contains(slot));
  }

  /// Open items with no cadence or reminder. Never also on Schedule.
  static bool isActiveChallenge(GiftActivity gift, [DateTime? now]) {
    if (gift.status != GiftStatus.active) return false;
    if (hasScheduleCadence(gift)) return false;
    if (GiftTracking.isCompletedInPeriod(gift, now)) return false;
    return true;
  }

  static bool giftDueToday(GiftActivity gift, [DateTime? now]) {
    return isOnSchedule(gift, now) && GiftTracking.isDueToday(gift, now);
  }

  static bool giftDueThisWeek(GiftActivity gift, [DateTime? now]) {
    return isOnSchedule(gift, now) && GiftTracking.isDueThisWeek(gift, now);
  }

  static bool practiceDueToday(
    GroupPracticeInstance practice, [
    DateTime? now,
  ]) {
    if (!practice.active) return false;
    final today = now ?? DateTime.now();
    if (GroupPracticeTracking.isDueNow(practice, today)) return true;
    if (practice.recurrence != GroupScheduleRecurrence.weekly) return false;
    if (practice.daysOfWeek.isEmpty) return false;
    final weekStart = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    for (var i = 0; i < today.weekday - 1; i++) {
      final day = weekStart.add(Duration(days: i));
      if (!GroupPracticeTracking.appliesOnDate(practice, day)) continue;
      final slots = GroupPracticeTracking.slotsForDate(practice, day);
      if (slots.any((slot) => !practice.completionSlots.contains(slot))) {
        return true;
      }
    }
    return false;
  }

  static bool practiceDueThisWeek(
    GroupPracticeInstance practice, [
    DateTime? now,
  ]) {
    if (!isPracticeOnSchedule(practice, now)) return false;
    if (practiceDueToday(practice, now)) return true;
    final today = now ?? DateTime.now();
    final weekStart = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    for (var i = 0; i < 7; i++) {
      if (GroupPracticeTracking.appliesOnDate(
        practice,
        weekStart.add(Duration(days: i)),
      )) {
        return true;
      }
    }
    return false;
  }

  static bool giftCompletedToday(GiftActivity gift, [DateTime? now]) {
    return GiftTracking.isCompletedToday(gift, now);
  }

  static bool practiceCompletedToday(
    GroupPracticeInstance practice, [
    DateTime? now,
  ]) {
    final today = now ?? DateTime.now();
    final prefix = '${GroupPracticeTracking.dateKey(today)}@';
    return practice.completionSlots.any((slot) => slot.startsWith(prefix));
  }

  static bool hourCompletedToday(ServiceHourEntry entry, [DateTime? now]) {
    if (!entry.countsTowardTotal) return false;
    final today = now ?? DateTime.now();
    return entry.date.year == today.year &&
        entry.date.month == today.month &&
        entry.date.day == today.day;
  }

  static GiftDateWindow rangeFor(GiftDoneRange range, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (range) {
      case GiftDoneRange.today:
        return GiftDateWindow(start: today, end: today);
      case GiftDoneRange.thisWeek:
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return GiftDateWindow(
          start: weekStart,
          end: weekStart.add(const Duration(days: 6)),
        );
      case GiftDoneRange.thisSemester:
        return semesterContaining(today);
      case GiftDoneRange.all:
        return GiftDateWindow(
          start: DateTime(2000, 1, 1),
          end: today,
        );
    }
  }

  /// Northern academic calendar: Spring Jan–May, Summer Jun–Jul, Fall Aug–Dec.
  static GiftDateWindow semesterContaining(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (d.month <= 5) {
      return GiftDateWindow(
        start: DateTime(d.year, 1, 1),
        end: DateTime(d.year, 5, 31),
      );
    }
    if (d.month <= 7) {
      return GiftDateWindow(
        start: DateTime(d.year, 6, 1),
        end: DateTime(d.year, 7, 31),
      );
    }
    return GiftDateWindow(
      start: DateTime(d.year, 8, 1),
      end: DateTime(d.year, 12, 31),
    );
  }

  static bool _dayInRange(DateTime day, GiftDateWindow range) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  static DateTime? latestGiftCompletionInRange(
    GiftActivity gift,
    GiftDoneRange range, [
    DateTime? now,
  ]) {
    final window = rangeFor(range, now ?? DateTime.now());
    DateTime? latest;
    for (final key in gift.completionDates) {
      final day = GiftTracking.parseDateKey(key);
      if (!_dayInRange(day, window)) continue;
      if (latest == null || day.isAfter(latest)) latest = day;
    }
    if (latest == null &&
        gift.status == GiftStatus.completed &&
        gift.completedAt != null &&
        _dayInRange(gift.completedAt!, window)) {
      latest = DateTime(
        gift.completedAt!.year,
        gift.completedAt!.month,
        gift.completedAt!.day,
      );
    }
    return latest;
  }

  static bool giftOnDoneTab(
    GiftActivity gift,
    GiftDoneRange range, [
    DateTime? now,
  ]) {
    return latestGiftCompletionInRange(gift, range, now) != null;
  }

  static bool hourOnDoneTab(
    ServiceHourEntry entry,
    GiftDoneRange range, [
    DateTime? now,
  ]) {
    if (!entry.countsTowardTotal) return false;
    final window = rangeFor(range, now ?? DateTime.now());
    return _dayInRange(entry.date, window);
  }

  static bool practiceOnDoneTab(
    GroupPracticeInstance practice,
    GiftDoneRange range, [
    DateTime? now,
  ]) {
    return latestPracticeCompletionInRange(practice, range, now) != null;
  }

  static DateTime? latestPracticeCompletionInRange(
    GroupPracticeInstance practice,
    GiftDoneRange range, [
    DateTime? now,
  ]) {
    final window = rangeFor(range, now ?? DateTime.now());
    DateTime? latest;
    for (final slot in practice.completionSlots) {
      final key = slot.split('@').first;
      final day = GiftTracking.parseDateKey(key);
      if (!_dayInRange(day, window)) continue;
      if (latest == null || day.isAfter(latest)) latest = day;
    }
    return latest;
  }

  static List<GiftActivity> scheduleGifts(
    List<GiftActivity> gifts, [
    DateTime? now,
    GiftScheduleFilter filter = GiftScheduleFilter.allScheduled,
  ]) {
    return gifts.where((g) {
      if (!isOnSchedule(g, now)) return false;
      switch (filter) {
        case GiftScheduleFilter.dueToday:
          return giftDueToday(g, now);
        case GiftScheduleFilter.thisWeek:
          return giftDueThisWeek(g, now);
        case GiftScheduleFilter.allScheduled:
          return true;
      }
    }).toList();
  }

  static List<GroupPracticeInstance> schedulePractices(
    List<GroupPracticeInstance> practices, [
    DateTime? now,
    GiftScheduleFilter filter = GiftScheduleFilter.allScheduled,
  ]) {
    return practices.where((p) {
      if (!isPracticeOnSchedule(p, now)) return false;
      switch (filter) {
        case GiftScheduleFilter.dueToday:
          return practiceDueToday(p, now);
        case GiftScheduleFilter.thisWeek:
          return practiceDueThisWeek(p, now);
        case GiftScheduleFilter.allScheduled:
          return true;
      }
    }).toList();
  }

  static int dueTodayCount({
    required List<GiftActivity> gifts,
    required List<GroupPracticeInstance> practices,
    DateTime? now,
  }) {
    return scheduleGifts(gifts, now, GiftScheduleFilter.dueToday).length +
        schedulePractices(practices, now, GiftScheduleFilter.dueToday).length;
  }

  static List<GiftActivity> activeChallenges(
    List<GiftActivity> gifts, [
    DateTime? now,
  ]) {
    return gifts.where((g) => isActiveChallenge(g, now)).toList();
  }

  static List<GiftDoneRow> completedTodayRows({
    required List<GiftActivity> gifts,
    required List<GroupPracticeInstance> practices,
    required List<ServiceHourEntry> hours,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final rows = <GiftDoneRow>[
      for (final gift in gifts)
        if (giftCompletedToday(gift, today))
          GiftDoneRow.gift(
            activity: gift,
            completedOn: GiftTracking.parseDateKey(GiftTracking.dateKey(today)),
          ),
      for (final practice in practices)
        if (practiceCompletedToday(practice, today))
          GiftDoneRow.practice(
            instance: practice,
            completedOn: GiftTracking.parseDateKey(GiftTracking.dateKey(today)),
          ),
      for (final entry in hours)
        if (hourCompletedToday(entry, today))
          GiftDoneRow.hours(entry: entry, completedOn: entry.date),
    ];
    rows.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return rows;
  }

  static List<GiftDoneRow> doneRows({
    required List<GiftActivity> gifts,
    required List<GroupPracticeInstance> practices,
    required List<ServiceHourEntry> hours,
    required GiftDoneRange range,
    DateTime? now,
  }) {
    final when = now ?? DateTime.now();
    final rows = <GiftDoneRow>[
      for (final gift in gifts)
        if (latestGiftCompletionInRange(gift, range, when) != null)
          GiftDoneRow.gift(
            activity: gift,
            completedOn: latestGiftCompletionInRange(gift, range, when)!,
          ),
      for (final practice in practices)
        if (latestPracticeCompletionInRange(practice, range, when) != null)
          GiftDoneRow.practice(
            instance: practice,
            completedOn: latestPracticeCompletionInRange(practice, range, when)!,
          ),
      for (final entry in hours)
        if (hourOnDoneTab(entry, range, when))
          GiftDoneRow.hours(entry: entry, completedOn: entry.date),
    ];
    rows.sort((a, b) {
      final byDate = b.completedOn.compareTo(a.completedOn);
      if (byDate != 0) return byDate;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return rows;
  }
}

/// One completed Gift, group practice, or counted service-hour entry.
class GiftDoneRow {
  const GiftDoneRow.gift({
    required GiftActivity activity,
    required this.completedOn,
  })  : gift = activity,
        practice = null,
        hours = null;

  const GiftDoneRow.practice({
    required GroupPracticeInstance instance,
    required this.completedOn,
  })  : gift = null,
        practice = instance,
        hours = null;

  const GiftDoneRow.hours({
    required ServiceHourEntry entry,
    required this.completedOn,
  })  : gift = null,
        practice = null,
        hours = entry;

  final GiftActivity? gift;
  final GroupPracticeInstance? practice;
  final ServiceHourEntry? hours;
  final DateTime completedOn;

  String get id => gift?.id ?? practice?.id ?? hours!.id;

  String get title {
    if (gift != null) return gift!.title;
    if (practice != null) return practice!.title;
    return 'Service hours';
  }

  bool get isGift => gift != null;
  bool get isPractice => practice != null;
  bool get isHours => hours != null;
}

class GiftDateWindow {
  const GiftDateWindow({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}
