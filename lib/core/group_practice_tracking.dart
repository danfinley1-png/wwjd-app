import '../admin/models/group_schedule.dart';
import '../models/group_practice_instance.dart';
import 'gift_reminder_utils.dart';

/// Due / completion logic for group practice schedules (multiple daily times).
class GroupPracticeTracking {
  GroupPracticeTracking._();

  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String slotKey(DateTime date, String time) {
    return '${dateKey(date)}@${_normalizeTime(time)}';
  }

  static String _normalizeTime(String time) {
    return GiftReminderUtils.formatStoredTime(GiftReminderUtils.parseTime(time));
  }

  static bool appliesOnDate(GroupPracticeInstance practice, DateTime date) {
    if (!practice.active) return false;
    switch (practice.recurrence) {
      case GroupScheduleRecurrence.daily:
        return true;
      case GroupScheduleRecurrence.weekly:
        if (practice.daysOfWeek.isEmpty) return true;
        final weekday = GiftReminderUtils.weekdayNames[date.weekday - 1];
        return practice.daysOfWeek
            .map((d) => d.toLowerCase())
            .contains(weekday.toLowerCase());
    }
  }

  static List<String> slotsForDate(GroupPracticeInstance practice, DateTime date) {
    if (!appliesOnDate(practice, date)) return const [];
    return practice.times.map((t) => slotKey(date, t)).toList();
  }

  static bool isSlotComplete(GroupPracticeInstance practice, String slot) {
    return practice.completionSlots.contains(slot);
  }

  static bool isDueNow(GroupPracticeInstance practice, [DateTime? now]) {
    final today = now ?? DateTime.now();
    final slots = slotsForDate(practice, today);
    if (slots.isEmpty) return false;
    return slots.any((slot) => !isSlotComplete(practice, slot));
  }

  static List<GroupPracticeInstance> dueToday(
    List<GroupPracticeInstance> practices, [
    DateTime? now,
  ]) {
    return practices.where((p) => p.active && isDueNow(p, now)).toList();
  }

  static List<GroupPracticeInstance> activePractices(
    List<GroupPracticeInstance> practices,
  ) {
    return practices.where((p) => p.active).toList();
  }

  static String timesSummary(GroupPracticeInstance practice) {
    if (practice.times.isEmpty) return 'No times set';
    final labels =
        practice.times.map(GiftReminderUtils.formatDisplayTime).join(', ');
    switch (practice.recurrence) {
      case GroupScheduleRecurrence.daily:
        return 'Daily at $labels';
      case GroupScheduleRecurrence.weekly:
        if (practice.daysOfWeek.isEmpty) {
          return 'Weekly at $labels';
        }
        return '${practice.daysOfWeek.join(', ')} at $labels';
    }
  }

  static String nextDueSlotLabel(GroupPracticeInstance practice, [DateTime? now]) {
    final today = now ?? DateTime.now();
    for (final time in practice.times) {
      final slot = slotKey(today, time);
      if (!isSlotComplete(practice, slot)) {
        return GiftReminderUtils.formatDisplayTime(time);
      }
    }
    return 'Complete';
  }

  static GroupPracticeInstance markNextSlotComplete(
    GroupPracticeInstance practice, [
    DateTime? now,
  ]) {
    final today = now ?? DateTime.now();
    final slots = slotsForDate(practice, today);

    for (final time in practice.times) {
      final slot = slotKey(today, time);
      if (!slots.contains(slot)) continue;
      if (!practice.completionSlots.contains(slot)) {
        final updated = [...practice.completionSlots, slot];
        final total = practice.totalCompletions + 1;
        final allTodayDone = slots.every(updated.contains);
        final streak =
            allTodayDone ? practice.currentStreak + 1 : practice.currentStreak;
        return practice.copyWith(
          completionSlots: updated,
          lastCompleted: today,
          totalCompletions: total,
          currentStreak: streak,
        );
      }
    }

    return practice;
  }
}
