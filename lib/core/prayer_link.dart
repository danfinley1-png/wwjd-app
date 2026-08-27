import 'app_links.dart';

/// Deep links to a canonical prayer in the Catholic prayer library.
class PrayerLink {
  PrayerLink._();

  static const String pathPrefix = '/prayer';
  static const String listPath = '/prayers';

  /// In-app route path (GoRouter).
  static String path(String prayerId) => '$pathPrefix/${prayerId.trim()}';

  /// Full HTTPS URL for sharing and forwarding.
  static String url(String prayerId) => AppLinks.absolutePath(path(prayerId));

  static String shareText({
    required String displayName,
    required String prayerId,
  }) {
    return '$displayName\n${url(prayerId)}';
  }
}
