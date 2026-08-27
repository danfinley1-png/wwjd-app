import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/gift_activity.dart';
import 'gift_activity_link.dart';
import 'gift_tracking.dart';

/// Helpers for gift reminder time, labels, and stable notification IDs.
class GiftReminderUtils {
  GiftReminderUtils._();

  static const weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const icsWeekdayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  /// Default gentle morning reminder when none is set.
  static TimeOfDay defaultTime = const TimeOfDay(hour: 7, minute: 0);

  /// Parses stored reminder time (`07:00`, `7:00 AM`, etc.).
  static TimeOfDay parseTime(String? value) {
    if (value == null || value.trim().isEmpty) return defaultTime;
    final trimmed = value.trim();

    final amPm = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final match = amPm.firstMatch(trimmed);
    if (match != null) {
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!.toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }

    final twentyFour = RegExp(r'^(\d{1,2}):(\d{2})$');
    final match24 = twentyFour.firstMatch(trimmed);
    if (match24 != null) {
      return TimeOfDay(
        hour: int.parse(match24.group(1)!),
        minute: int.parse(match24.group(2)!),
      );
    }

    return defaultTime;
  }

  /// Stores time as 24-hour `HH:mm` for Firestore consistency.
  static String formatStoredTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Friendly label, e.g. "7:00 AM".
  static String formatDisplayTime(String? value) {
    final time = parseTime(value);
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  /// Pastoral summary shown in UI, e.g. "Every day at 7:00 AM".
  static String recurrenceSummary(GiftActivity gift) {
    final timeLabel = formatDisplayTime(gift.specificTime);
    if (GiftTracking.isOneTime(gift)) {
      return 'Once at $timeLabel';
    }
    switch (gift.frequency.toLowerCase()) {
      case 'weekly':
        if (gift.daysOfWeek.isEmpty) {
          return 'Weekly at $timeLabel';
        }
        final days = gift.daysOfWeek.join(', ');
        return 'Weekly on $days at $timeLabel';
      case 'monthly':
        return 'Monthly at $timeLabel';
      default:
        return 'Every day at $timeLabel';
    }
  }

  static String notificationTitle() => 'WWJD-DI · Kingdom Challenge';

  static String notificationBody(GiftActivity gift) {
    return '${gift.title} — ${GiftActivityLink.notificationBodySuffix(gift.id)}';
  }

  /// Stable positive int for flutter_local_notifications.
  static int notificationId(GiftActivity gift, {int weekdayIndex = 0}) {
    return (gift.id.hashCode.abs() + weekdayIndex * 9973) % 2147483646 + 1;
  }

  static List<int> weekdayIndexesForGift(GiftActivity gift) {
    if (gift.frequency.toLowerCase() != 'weekly' ||
        gift.daysOfWeek.isEmpty) {
      return [0];
    }
    final indexes = <int>[];
    for (var i = 0; i < weekdayNames.length; i++) {
      final name = weekdayNames[i].toLowerCase();
      if (gift.daysOfWeek.any((d) => d.toLowerCase() == name)) {
        indexes.add(i);
      }
    }
    return indexes.isEmpty ? [0] : indexes;
  }

  static List<String> icsByDayCodes(GiftActivity gift) {
    if (gift.frequency.toLowerCase() != 'weekly' ||
        gift.daysOfWeek.isEmpty) {
      return [];
    }
    final codes = <String>[];
    for (var i = 0; i < weekdayNames.length; i++) {
      final name = weekdayNames[i].toLowerCase();
      if (gift.daysOfWeek.any((d) => d.toLowerCase() == name)) {
        codes.add(icsWeekdayCodes[i]);
      }
    }
    return codes;
  }
}
