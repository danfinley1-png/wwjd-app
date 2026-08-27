import '../models/gift_activity.dart';
import '../models/gift_status.dart';

/// Recurrence bucket for due / completion tracking.
enum GiftDuePeriod { daily, weekly, monthly, oneTime }

/// Pure helpers for gift due dates, completions, and streaks.
class GiftTracking {
  GiftTracking._();

  static String dateKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return DateTime.now();
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static GiftDuePeriod duePeriod(GiftActivity gift) {
    if (isOneTime(gift)) return GiftDuePeriod.oneTime;
    switch (gift.frequency.toLowerCase()) {
      case 'weekly':
        return GiftDuePeriod.weekly;
      case 'monthly':
        return GiftDuePeriod.monthly;
      default:
        return GiftDuePeriod.daily;
    }
  }

  static bool isCompletedOnDate(GiftActivity gift, DateTime date) {
    final key = dateKey(date);
    return gift.completionDates.contains(key);
  }

  static bool isCompletedToday(GiftActivity gift, [DateTime? now]) {
    return isCompletedOnDate(gift, now ?? DateTime.now());
  }

  static bool isCompletedThisWeek(GiftActivity gift, [DateTime? now]) {
    return _completedInSameWeek(gift, now ?? DateTime.now());
  }

  static bool isCompletedThisMonth(GiftActivity gift, [DateTime? now]) {
    return _completedInSameMonth(gift, now ?? DateTime.now());
  }

  /// True when the gift was completed within its frequency period
  /// (today / this calendar week / this calendar month).
  static bool isCompletedInPeriod(GiftActivity gift, [DateTime? now]) {
    final today = now ?? DateTime.now();
    switch (duePeriod(gift)) {
      case GiftDuePeriod.daily:
        return isCompletedToday(gift, today);
      case GiftDuePeriod.weekly:
        return isCompletedThisWeek(gift, today);
      case GiftDuePeriod.monthly:
        return isCompletedThisMonth(gift, today);
      case GiftDuePeriod.oneTime:
        return gift.status == GiftStatus.completed || gift.isCompleted;
    }
  }

  static bool isOneTime(GiftActivity gift) {
    final f = gift.frequency.toLowerCase();
    return f == 'once' || f == 'one-time' || f == 'one time';
  }

  /// Whether the gift still needs attention in its current period.
  static bool isDue(GiftActivity gift, [DateTime? now]) {
    final today = now ?? DateTime.now();
    if (gift.status != GiftStatus.active) return false;
    if (isCompletedInPeriod(gift, today)) return false;

    if (isOneTime(gift)) {
      if (gift.status == GiftStatus.completed || gift.isCompleted) return false;
      if (gift.dueDate == null) return true;
      final due = gift.dueDate!;
      final dueDay = DateTime(due.year, due.month, due.day);
      final todayDay = DateTime(today.year, today.month, today.day);
      return !todayDay.isBefore(dueDay);
    }

    switch (duePeriod(gift)) {
      case GiftDuePeriod.daily:
        return true;
      case GiftDuePeriod.weekly:
        return _isDueWeekly(gift, today);
      case GiftDuePeriod.monthly:
        return true;
      case GiftDuePeriod.oneTime:
        return false;
    }
  }

  /// Backward-compatible alias — daily = today; weekly/monthly = current period.
  static bool isDueToday(GiftActivity gift, [DateTime? now]) => isDue(gift, now);

  static bool _isDueWeekly(GiftActivity gift, DateTime today) {
    if (gift.daysOfWeek.isNotEmpty) {
      final weekdayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final todayName = weekdayNames[today.weekday - 1];
      return gift.daysOfWeek.any(
        (d) => d.toLowerCase() == todayName.toLowerCase(),
      );
    }
    return true;
  }

  static bool _completedInSameWeek(GiftActivity gift, DateTime today) {
    final weekStart = _weekStart(today);
    final weekEnd = weekStart.add(const Duration(days: 7));
    return gift.completionDates.any((key) {
      final d = parseDateKey(key);
      return !d.isBefore(weekStart) && d.isBefore(weekEnd);
    });
  }

  static bool _completedInSameMonth(GiftActivity gift, DateTime today) {
    return gift.completionDates.any((key) {
      final d = parseDateKey(key);
      return d.year == today.year && d.month == today.month;
    });
  }

  /// Monday 00:00 of the calendar week containing [date].
  static DateTime _weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static String dueStatusLabel(GiftActivity gift, [DateTime? now]) {
    final today = now ?? DateTime.now();
    if (isCompletedInPeriod(gift, today)) {
      return completedStatusLabel(gift, today);
    }
    if (!isDue(gift, today)) return '';

    switch (duePeriod(gift)) {
      case GiftDuePeriod.daily:
        return 'Due today';
      case GiftDuePeriod.weekly:
        return 'Due this week';
      case GiftDuePeriod.monthly:
        return 'Due this month';
      case GiftDuePeriod.oneTime:
        return 'Due';
    }
  }

  static String completedStatusLabel(GiftActivity gift, [DateTime? now]) {
    switch (duePeriod(gift)) {
      case GiftDuePeriod.daily:
        return 'Completed today';
      case GiftDuePeriod.weekly:
        return 'Completed this week';
      case GiftDuePeriod.monthly:
        return 'Completed this month';
      case GiftDuePeriod.oneTime:
        return 'Completed';
    }
  }

  static String completeActionLabel(GiftActivity gift) {
    switch (duePeriod(gift)) {
      case GiftDuePeriod.daily:
        return 'Complete for today';
      case GiftDuePeriod.weekly:
        return 'Complete for this week';
      case GiftDuePeriod.monthly:
        return 'Complete for this month';
      case GiftDuePeriod.oneTime:
        return 'Mark as complete';
    }
  }

  static String dueNowSectionSubtitle(List<GiftActivity> gifts, [DateTime? now]) {
    final due = gifts.where((g) => isDue(g, now)).length;
    if (due == 0) return 'All caught up for now — well done!';
    if (due == 1) return '1 gift needs attention';
    return '$due gifts need attention';
  }

  /// Consecutive calendar days ending on the most recent completion.
  static int calculateStreak(
    List<String> completionDates, {
    DateTime? now,
  }) {
    if (completionDates.isEmpty) return 0;

    final today = now ?? DateTime.now();
    final sorted = completionDates.toSet().toList()..sort();
    var cursor = parseDateKey(sorted.last);
    final todayKey = dateKey(today);
    final yesterdayKey = dateKey(today.subtract(const Duration(days: 1)));

    if (sorted.last != todayKey && sorted.last != yesterdayKey) {
      return 0;
    }

    if (sorted.last == yesterdayKey) {
      cursor = parseDateKey(yesterdayKey);
    }

    var streak = 0;
    final set = sorted.toSet();
    while (set.contains(dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static GiftActivity applyCompletion(
    GiftActivity gift, {
    DateTime? completedAt,
  }) {
    final now = completedAt ?? DateTime.now();
    final key = dateKey(now);

    if (gift.completionDates.contains(key)) {
      return gift;
    }

    final dates = [...gift.completionDates, key]..sort();
    final total = dates.length;
    final streak = calculateStreak(dates, now: now);
    final oneTime = isOneTime(gift);

    return gift.copyWith(
      completionDates: dates,
      lastCompleted: now,
      totalCompletions: total,
      currentStreak: streak,
      completedAt: now,
      isCompleted: oneTime ? true : gift.isCompleted,
      status: oneTime ? GiftStatus.completed : gift.status,
    );
  }

  static List<GiftActivity> todayGifts(
    List<GiftActivity> gifts, [
    DateTime? now,
  ]) {
    return gifts.where((g) => isDue(g, now)).toList();
  }

  /// Gifts in the Due Now section: due in period or already completed in period.
  static List<GiftActivity> todaySectionGifts(
    List<GiftActivity> gifts, [
    DateTime? now,
  ]) {
    return gifts.where((g) {
      if (g.status != GiftStatus.active) return false;
      return isDue(g, now) || isCompletedInPeriod(g, now);
    }).toList();
  }

  static List<GiftActivity> activeGifts(List<GiftActivity> gifts) {
    return gifts.where((g) => g.status == GiftStatus.active).toList();
  }

  static GiftAggregateStats aggregateStats(
    List<GiftActivity> gifts, [
    DateTime? now,
  ]) {
    var totalCompletions = 0;
    var bestStreak = 0;
    var completedInPeriod = 0;

    for (final gift in gifts) {
      totalCompletions += gift.totalCompletions;
      if (gift.currentStreak > bestStreak) {
        bestStreak = gift.currentStreak;
      }
      if (gift.status != GiftStatus.active) continue;
      if (isCompletedInPeriod(gift, now)) completedInPeriod++;
    }

    return GiftAggregateStats(
      totalCompletions: totalCompletions,
      bestStreak: bestStreak,
      completedTodayCount: completedInPeriod,
      dueTodayCount: _dueNowTotal(gifts, now),
    );
  }

  static int _dueNowTotal(List<GiftActivity> gifts, [DateTime? now]) {
    return gifts.where((g) {
      if (g.status != GiftStatus.active) return false;
      return isDue(g, now) || isCompletedInPeriod(g, now);
    }).length;
  }
}

class GiftAggregateStats {
  final int totalCompletions;
  final int bestStreak;
  /// Completed within each gift's current period (day / week / month).
  final int completedTodayCount;
  /// Active gifts in the Due Now section.
  final int dueTodayCount;

  const GiftAggregateStats({
    required this.totalCompletions,
    required this.bestStreak,
    required this.completedTodayCount,
    required this.dueTodayCount,
  });
}
