import '../catholic_prayers/catholic_prayer_catalog.dart';
import '../prayer_link.dart';
import '../../models/gift_activity.dart';
import '../../models/group_practice_instance.dart';

/// Links Gifts and group practices to canonical prayers in the WWJD-DI library.
class PrayerGiftLink {
  PrayerGiftLink._();

  /// Resolves a stored or detected prayer id for a gift activity.
  static String? resolvePrayerId(GiftActivity gift) {
    final stored = gift.linkedPrayerId?.trim();
    if (stored != null && CatholicPrayerCatalog.byId(stored) != null) {
      return stored;
    }
    return detectPrayerId(title: gift.title, description: gift.description);
  }

  static CatholicPrayer? resolvePrayer(GiftActivity gift) {
    final id = resolvePrayerId(gift);
    return id == null ? null : CatholicPrayerCatalog.byId(id);
  }

  /// Resolves a prayer for a synced group practice.
  static String? resolveGroupPracticePrayerId(GroupPracticeInstance practice) {
    final fromLink = prayerIdFromUrl(practice.practiceLink);
    if (fromLink != null && CatholicPrayerCatalog.byId(fromLink) != null) {
      return fromLink;
    }
    return detectPrayerId(
      title: practice.title,
      description: practice.description,
    );
  }

  static CatholicPrayer? resolveGroupPracticePrayer(
    GroupPracticeInstance practice,
  ) {
    final id = resolveGroupPracticePrayerId(practice);
    return id == null ? null : CatholicPrayerCatalog.byId(id);
  }

  /// Detects a catalog prayer from title and optional description text.
  static String? detectPrayerId({
    required String title,
    String? description,
  }) {
    final haystack = _normalize('$title ${description ?? ''}');
    if (haystack.isEmpty) return null;

    CatholicPrayer? best;
    var bestLength = 0;

    for (final prayer in CatholicPrayerCatalog.prayers) {
      final candidates = [
        ...prayer.aliases,
        _normalize(prayer.displayName),
      ];
      for (final alias in candidates) {
        if (alias.isEmpty) continue;
        if (haystack.contains(alias) && alias.length > bestLength) {
          best = prayer;
          bestLength = alias.length;
        }
      }
    }

    return best?.id;
  }

  /// Ensures [gift] has an up-to-date `linkedPrayerId` before persistence.
  /// Preserves an explicit catalog link; otherwise auto-detects from text.
  static GiftActivity enrich(GiftActivity gift) {
    final stored = gift.linkedPrayerId?.trim();
    if (stored != null && CatholicPrayerCatalog.byId(stored) != null) {
      return gift;
    }
    final detected = detectPrayerId(
      title: gift.title,
      description: gift.description,
    );
    if (detected == null) return gift;
    return gift.copyWith(linkedPrayerId: detected);
  }

  /// Stable prayer URL for shares and calendar entries.
  static String? urlForGift(GiftActivity gift) {
    final id = resolvePrayerId(gift);
    return id == null ? null : PrayerLink.url(id);
  }

  /// Calendar-friendly line with a clickable prayer URL.
  static String? calendarLineForGift(GiftActivity gift) {
    final prayer = resolvePrayer(gift);
    final url = urlForGift(gift);
    if (prayer == null || url == null) return null;
    return 'Prayer text (${prayer.displayName}): $url';
  }

  /// Share-friendly line appended to gift share text.
  static String? shareLineForGift(GiftActivity gift) {
    return calendarLineForGift(gift);
  }

  static String? prayerIdFromUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments[segments.length - 2] == 'prayer') {
      return segments.last;
    }

    final match = RegExp(r'/prayer/([^/?#]+)').firstMatch(uri.path);
    return match?.group(1);
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[“”"]'), '"')
        .replaceAll(RegExp(r'[`´]'), "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
