import 'package:intl/intl.dart';

import '../models/gift_activity.dart';
import 'config.dart';
import 'gift_activity_link.dart';
import 'gift_reminder_utils.dart';
import 'catholic_prayers/prayer_gift_link.dart';
import 'gift_tracking.dart';

/// Builds a downloadable RFC 5545 calendar file for a Kingdom Challenge gift.
class GiftIcs {
  GiftIcs._();

  static String build(GiftActivity gift, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final time = GiftReminderUtils.parseTime(gift.specificTime);
    var start = DateTime(
      reference.year,
      reference.month,
      reference.day,
      time.hour,
      time.minute,
    );
    if (start.isBefore(reference)) {
      start = start.add(const Duration(days: 1));
    }

    final uid = 'gift-${gift.id}@wwjd-di';
    final summary = _escape('WWJD-DI · ${gift.title}');
    final activityUrl = GiftActivityLink.url(gift.id);
    final description = _escape(_description(gift, activityUrl));
    final dtStart = _formatLocal(start);
    final dtStamp = _formatUtc(reference.toUtc());
    final rrule = _rrule(gift);

    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//WWJD-DI//Kingdom Challenge//EN')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH')
      ..writeln('X-WR-CALNAME:WWJD-DI Gifts')
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:$uid')
      ..writeln('DTSTAMP:$dtStamp')
      ..writeln('DTSTART:$dtStart')
      ..writeln('DURATION:PT15M')
      ..writeln('SUMMARY:$summary')
      ..writeln('DESCRIPTION:$description')
      ..writeln('URL:$activityUrl');
    if (rrule != null) {
      buffer.writeln('RRULE:$rrule');
    }
    buffer
      ..writeln('END:VEVENT')
      ..writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static String filenameFor(GiftActivity gift) {
    final slug = gift.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final safe = slug.isEmpty ? gift.id.substring(0, 8) : slug;
    return 'wwjd-di-gift-$safe.ics';
  }

  static String _description(GiftActivity gift, String activityUrl) {
    final parts = <String>[
      AppConfig.tagline,
      '',
      gift.description.trim(),
    ];
    if (gift.note != null && gift.note!.trim().isNotEmpty) {
      parts.add('');
      parts.add('My note: ${gift.note!.trim()}');
    }
    parts.add('');
    parts.add(GiftActivityLink.calendarDescriptionLine(gift.id));
    final prayerLine = PrayerGiftLink.calendarLineForGift(gift);
    if (prayerLine != null) {
      parts.add('');
      parts.add(prayerLine);
    }
    parts.add('');
    parts.add(activityUrl);
    parts.add('');
    parts.add('— ${AppConfig.appName} · Sharing My Gifts');
    return parts.join('\n');
  }

  static String? _rrule(GiftActivity gift) {
    if (GiftTracking.isOneTime(gift)) return null;

    switch (gift.frequency.toLowerCase()) {
      case 'weekly':
        final byDay = GiftReminderUtils.icsByDayCodes(gift);
        if (byDay.isEmpty) return 'FREQ=WEEKLY';
        return 'FREQ=WEEKLY;BYDAY=${byDay.join(',')}';
      case 'monthly':
        return 'FREQ=MONTHLY';
      default:
        return 'FREQ=DAILY';
    }
  }

  static String _formatLocal(DateTime dt) {
    return DateFormat("yyyyMMdd'T'HHmmss").format(dt);
  }

  static String _formatUtc(DateTime dt) {
    return DateFormat("yyyyMMdd'T'HHmmss'Z'").format(dt);
  }

  static String _escape(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll('\n', r'\n')
        .replaceAll(',', r'\,')
        .replaceAll(';', r'\;');
  }
}
