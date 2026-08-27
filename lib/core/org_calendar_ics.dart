import 'package:intl/intl.dart';

import '../admin/models/org_calendar_event.dart';
import 'config.dart';

/// Builds a downloadable RFC 5545 calendar file for one school/org event.
class OrgCalendarIcs {
  OrgCalendarIcs._();

  static String build(OrgCalendarEvent event, {String? organizationName}) {
    final now = DateTime.now().toUtc();
    final uid = 'orgcal-${event.organizationId}-${event.id}@wwjd-di';
    final summary = _escape(event.title);
    final description = _escape(_description(event, organizationName));
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//WWJD-DI//School Calendar//EN')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH')
      ..writeln('X-WR-CALNAME:WWJD-DI School Calendar')
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:$uid')
      ..writeln('DTSTAMP:${_formatUtc(now)}');

    if (event.allDay) {
      buffer
        ..writeln('DTSTART;VALUE=DATE:${_formatDate(event.startAt)}')
        ..writeln('DTEND;VALUE=DATE:${_formatDate(event.endAt)}');
    } else {
      buffer
        ..writeln('DTSTART:${_formatLocal(event.startAt)}')
        ..writeln('DTEND:${_formatLocal(event.endAt)}');
    }

    buffer.writeln('SUMMARY:$summary');
    buffer.writeln('DESCRIPTION:$description');
    if (event.location.trim().isNotEmpty) {
      buffer.writeln('LOCATION:${_escape(event.location.trim())}');
    }
    buffer
      ..writeln('CATEGORIES:${_escape(event.category.label)}')
      ..writeln('END:VEVENT')
      ..writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static String filenameFor(OrgCalendarEvent event) {
    final slug = event.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final safe = slug.isEmpty ? event.id : slug;
    return 'wwjd-di-org-$safe.ics';
  }

  static String _description(OrgCalendarEvent event, String? organizationName) {
    final parts = <String>[
      if (organizationName != null && organizationName.trim().isNotEmpty)
        organizationName.trim(),
      'WWJD-DI School / Organization Calendar',
      '',
      if (event.description.trim().isNotEmpty) event.description.trim(),
      if (event.description.trim().isNotEmpty) '',
      AppConfig.tagline,
    ];
    return parts.join('\n');
  }

  static String _formatDate(DateTime dt) {
    return DateFormat('yyyyMMdd').format(dt);
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
