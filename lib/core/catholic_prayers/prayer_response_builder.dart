import 'dart:convert';

import 'catholic_prayer_catalog.dart';
import 'prayer_request_detector.dart';

/// Builds a reverent, non-discernment response for direct prayer requests.
class PrayerResponseBuilder {
  PrayerResponseBuilder._();

  /// Full API-shaped response (markdown body + trailing ```json``` block).
  static String build(PrayerRequestMatch match) {
    final prayer = match.prayer;
    final body = _buildBody(prayer);
    final actions = _suggestedActions(prayer);
    final jsonBlock = jsonEncode({'suggestedActions': actions});

    return '$body\n\n```json\n$jsonBlock\n```';
  }

  static String _buildBody(CatholicPrayer prayer) {
    final attribution = prayer.attribution == null
        ? ''
        : '\n\n*${prayer.attribution}*';

    return '''**${prayer.displayName}**

${prayer.body}$attribution

---

*This is the traditional Catholic text of the ${prayer.displayName}, offered here for prayer and devotion.*

**Kingdom Challenge**

Make the ${prayer.displayName} a regular practice this week: choose a consistent time each day to pray it slowly and with attention, entrusting the day to Christ.''';
  }

  static List<Map<String, String>> _suggestedActions(CatholicPrayer prayer) {
    return [
      {
        'title': 'Daily ${prayer.displayName}',
        'description':
            'Pray the ${prayer.displayName} at the same time each day this week, '
            'offering one intention for the Church and one for someone in need.',
        'frequency': 'Daily',
      },
      {
        'title': 'Pray With Another',
        'description':
            'Invite a family member or friend to pray the ${prayer.displayName} '
            'together once this week — in person, by phone, or before a shared meal.',
        'frequency': 'Once',
      },
    ];
  }
}
