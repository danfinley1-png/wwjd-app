import '../../models/pastoral_insights_models.dart';
import '../../models/pastoral_theme.dart';
import 'question_theme_aggregator.dart';

/// Labeled synthetic records for admin preview only — never live questions.
class PastoralInsightsDemoData {
  PastoralInsightsDemoData._();

  static List<AnonymizedConversationRecord>? _cache;
  static List<QuestionThemeEvent>? _eventCache;

  static List<AnonymizedConversationRecord> records({DateTime? now}) {
    return _cache ??= _buildRecords(now ?? DateTime.now());
  }

  static List<QuestionThemeEvent> themeEvents({DateTime? now}) {
    return _eventCache ??= _buildEvents(now ?? DateTime.now());
  }

  static void resetCache() {
    _cache = null;
    _eventCache = null;
  }

  static List<AnonymizedConversationRecord> _buildRecords(DateTime now) {
    return themeEvents(now: now)
        .map(
          (e) => AnonymizedConversationRecord(
            id: e.userHash,
            theme: e.theme,
            recordedAt: e.recordedAt,
            organizationId: e.organizationId,
            ministryGroupId: e.groupId,
            isDemo: true,
          ),
        )
        .toList();
  }

  static List<QuestionThemeEvent> _buildEvents(DateTime now) {
    final output = <QuestionThemeEvent>[];
    const groups = [
      'st_marys_youth',
      'parish_confirmation',
      'campus_ministry',
    ];
    const orgId = 'synthetic_org';
    var n = 0;

    for (final theme in PastoralThemeCategory.values) {
      for (var user = 0; user < 12; user++) {
        final daysAgo = (user * 5 + theme.index * 2) % 80;
        output.add(
          QuestionThemeEvent(
            theme: theme,
            source: user.isEven
                ? QuestionThemeSource.seekingGodsWisdom
                : QuestionThemeSource.walkTogether,
            recordedAt: now.subtract(Duration(days: daysAgo)),
            userHash: 'synthetic_${theme.firestoreValue}_$user',
            organizationId: orgId,
            groupId: groups[user % groups.length],
          ),
        );
        n += 1;
      }
    }

    for (var i = 0; i < 24; i++) {
      output.add(
        QuestionThemeEvent(
          theme: PastoralThemeCategory.values[i % PastoralThemeCategory.values.length],
          source: i.isEven
              ? QuestionThemeSource.seekingGodsWisdom
              : QuestionThemeSource.walkTogether,
          recordedAt: now.subtract(Duration(days: i % 20)),
          userHash: 'synthetic_recent_$i',
          organizationId: orgId,
          groupId: groups[i % groups.length],
        ),
      );
      n += 1;
    }

    assert(n == output.length);
    return output;
  }
}
