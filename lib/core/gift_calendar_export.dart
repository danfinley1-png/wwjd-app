import 'gift_calendar_export_stub.dart'
    if (dart.library.html) 'gift_calendar_export_web.dart'
    if (dart.library.io) 'gift_calendar_export_io.dart' as impl;

/// Downloads or shares a `.ics` calendar file for a gift.
Future<void> exportGiftCalendarFile({
  required String filename,
  required String icsContent,
  String subject = 'WWJD-DI Kingdom Challenge',
}) {
  return impl.exportGiftCalendarFile(
    filename: filename,
    icsContent: icsContent,
    subject: subject,
  );
}

/// Downloads or shares a `.ics` file (school calendar or other events).
Future<void> exportCalendarFile({
  required String filename,
  required String icsContent,
  String subject = 'WWJD-DI Calendar',
}) {
  return exportGiftCalendarFile(
    filename: filename,
    icsContent: icsContent,
    subject: subject,
  );
}
