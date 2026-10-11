import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../models/saint_video.dart';

/// Civil calendar for saint feasts in America/New_York.
class SaintCalendar {
  SaintCalendar._();

  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  static tz.Location get _newYork {
    ensureInitialized();
    return tz.getLocation('America/New_York');
  }

  static tz.TZDateTime todayInNewYork([DateTime? reference]) {
    final base = reference ?? DateTime.now();
    final utc = base.toUtc();
    return tz.TZDateTime.from(utc, _newYork);
  }

  static bool hasFeastDate(SaintEntry saint) =>
      saint.feastMonth != null &&
      saint.feastDayOfMonth != null &&
      saint.feastMonth! >= 1 &&
      saint.feastMonth! <= 12 &&
      saint.feastDayOfMonth! >= 1 &&
      saint.feastDayOfMonth! <= 31;

  static bool isFeastToday(SaintEntry saint, [DateTime? reference]) {
    if (!hasFeastDate(saint)) return false;
    final today = todayInNewYork(reference);
    return saint.feastMonth == today.month &&
        saint.feastDayOfMonth == today.day;
  }

  /// Days until next occurrence of this feast (0 if today).
  static int daysUntilFeast(SaintEntry saint, [DateTime? reference]) {
    if (!hasFeastDate(saint)) return 9999;
    final today = todayInNewYork(reference);
    final thisYear = tz.TZDateTime(
      _newYork,
      today.year,
      saint.feastMonth!,
      saint.feastDayOfMonth!,
    );
    var target = thisYear;
    if (target.isBefore(today)) {
      target = tz.TZDateTime(
        _newYork,
        today.year + 1,
        saint.feastMonth!,
        saint.feastDayOfMonth!,
      );
    }
    return target.difference(today).inDays;
  }

  static int compareFeastOrder(SaintEntry a, SaintEntry b) {
    final sortA = a.sortDate?.trim().isNotEmpty == true
        ? a.sortDate!.trim()
        : _sortKeyFromFeast(a);
    final sortB = b.sortDate?.trim().isNotEmpty == true
        ? b.sortDate!.trim()
        : _sortKeyFromFeast(b);
    if (sortA != null && sortB != null) {
      return sortA.compareTo(sortB);
    }
    final daysA = daysUntilFeast(a);
    final daysB = daysUntilFeast(b);
    if (daysA != daysB) return daysA.compareTo(daysB);
    return a.name.compareTo(b.name);
  }

  static String? _sortKeyFromFeast(SaintEntry saint) {
    if (!hasFeastDate(saint)) return null;
    return '${saint.feastMonth!.toString().padLeft(2, '0')}-'
        '${saint.feastDayOfMonth!.toString().padLeft(2, '0')}';
  }

  static List<SaintEntry> publishedFeastFilms(List<SaintEntry> all) {
    return all.where((s) => s.isPublished && s.isFeastFilm).toList()
      ..sort(compareFeastOrder);
  }

  static SaintEntry? saintForToday(
    List<SaintEntry> published, [
    DateTime? reference,
  ]) {
    for (final saint in publishedFeastFilms(published)) {
      if (isFeastToday(saint, reference)) return saint;
    }
    return null;
  }

  static SaintEntry? nextUpcomingSaint(
    List<SaintEntry> published, [
    DateTime? reference,
  ]) {
    final films = publishedFeastFilms(published);
    SaintEntry? best;
    var bestDays = 9999;
    for (final saint in films) {
      if (isFeastToday(saint, reference)) continue;
      final days = daysUntilFeast(saint, reference);
      if (days < bestDays) {
        bestDays = days;
        best = saint;
      }
    }
    return best;
  }

  static String feastLabel(SaintEntry saint) {
    if (!hasFeastDate(saint)) {
      return saint.feastDayLabel.trim();
    }
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final month = months[saint.feastMonth!];
    final rank = saint.rank.trim();
    if (rank.isNotEmpty) {
      return '$month ${saint.feastDayOfMonth} · ${rank[0].toUpperCase()}${rank.substring(1)}';
    }
    return '$month ${saint.feastDayOfMonth}';
  }
}
