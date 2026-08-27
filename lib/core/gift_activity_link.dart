import 'app_links.dart';

/// Deep links to a Kingdom Challenge / Sharing My Gifts activity.
class GiftActivityLink {
  GiftActivityLink._();

  static const String pathPrefix = '/gift';

  /// In-app route path (GoRouter).
  static String path(String giftId) => '$pathPrefix/${giftId.trim()}';

  /// Full HTTPS URL for calendar entries and notification copy.
  static String url(String giftId) => AppLinks.absolutePath(path(giftId));

  static String calendarDescriptionLine(String giftId) =>
      'Open in WWJD-DI to mark complete and capture your reflection:\n${url(giftId)}';

  static String notificationBodySuffix(String giftId) =>
      'Tap to open in WWJD-DI and log your reflection.';
}
