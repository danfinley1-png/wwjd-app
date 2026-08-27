import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'gift_reminder_utils.dart';

/// Keeps gift titles in sync when they mention a time of day.
class GiftTitleTime {
  GiftTitleTime._();

  /// Matches times like `7:00 AM`, `7 AM`, `07:00`, or `at 7:30 PM`.
  static final RegExp _timePattern = RegExp(
    r'\b(at\s+)?(\d{1,2})(:\d{2})?\s*(AM|PM|am|pm|a\.m\.|p\.m\.)\b',
  );

  static final RegExp _twentyFourHourPattern = RegExp(
    r'\b(\d{1,2}:\d{2})\b',
  );

  static String _normalizeSpaces(String value) {
    return value
        .replaceAll('\u202f', ' ')
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// True when [title] appears to include a clock time.
  static bool titleReflectsTime(String title) {
    final trimmed = _normalizeSpaces(title);
    if (trimmed.isEmpty) return false;
    return _timePattern.hasMatch(trimmed) ||
        _twentyFourHourPattern.hasMatch(trimmed);
  }

  /// Labels that may appear in a title for a stored reminder time.
  static List<String> previousTimeLabels(String? storedTime) {
    if (storedTime == null || storedTime.trim().isEmpty) return const [];

    final parsed = GiftReminderUtils.parseTime(storedTime);
    final labels = <String>{};

    void add(String value) {
      final normalized = _normalizeSpaces(value);
      if (normalized.isNotEmpty) labels.add(normalized);
    }

    add(GiftReminderUtils.formatDisplayTime(storedTime));
    final reference = DateTime(2026, 1, 1, parsed.hour, parsed.minute);
    add(DateFormat.jm().format(reference));

    if (parsed.minute == 0) {
      final hour12 = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
      final period = parsed.hour < 12 ? 'AM' : 'PM';
      add('$hour12 $period');
      add('$hour12:00 $period');
    }

    for (final label in labels.toList()) {
      add(label.replaceAll(':00', ''));
      add(label.replaceAll(RegExp(r'\s+'), ' '));
    }

    return labels.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  /// Replaces an embedded time in [title] when the scheduled time changes.
  static String syncTitleWithTime({
    required String title,
    String? previousStoredTime,
    required TimeOfDay newTime,
  }) {
    if (!titleReflectsTime(title)) return title;

    final normalizedTitle = _normalizeSpaces(title);
    final newLabel = GiftReminderUtils.formatDisplayTime(
      GiftReminderUtils.formatStoredTime(newTime),
    );

    for (final oldLabel in previousTimeLabels(previousStoredTime)) {
      final index = normalizedTitle.toLowerCase().indexOf(oldLabel.toLowerCase());
      if (index >= 0) {
        return normalizedTitle.replaceRange(
          index,
          index + oldLabel.length,
          newLabel,
        );
      }
    }

    final amPmMatch = _timePattern.firstMatch(normalizedTitle);
    if (amPmMatch != null) {
      return normalizedTitle.replaceRange(
        amPmMatch.start,
        amPmMatch.end,
        newLabel,
      );
    }

    final twentyFourMatch = _twentyFourHourPattern.firstMatch(normalizedTitle);
    if (twentyFourMatch != null) {
      return normalizedTitle.replaceRange(
        twentyFourMatch.start,
        twentyFourMatch.end,
        GiftReminderUtils.formatStoredTime(newTime),
      );
    }

    return title;
  }
}
