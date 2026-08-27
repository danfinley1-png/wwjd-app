import '../../models/pastoral_insights_models.dart';
import '../../models/pastoral_theme.dart';

/// Fully synthetic demonstration records for Phase 1 insights.
/// Replace or disable when live anonymized ingestion is available.
class PastoralInsightsDemoData {
  PastoralInsightsDemoData._();

  static List<AnonymizedConversationRecord>? _cache;

  static List<AnonymizedConversationRecord> records({DateTime? now}) {
    return _cache ??= _buildRecords(now ?? DateTime.now());
  }

  static void resetCache() {
    _cache = null;
  }

  static List<AnonymizedConversationRecord> _buildRecords(DateTime now) {
    final output = <AnonymizedConversationRecord>[];
    var idCounter = 0;

    void addRecords({
      required PastoralThemeCategory theme,
      required int count,
      required String ministryGroupId,
      required String ageBand,
      required int maxDaysAgo,
    }) {
      for (var i = 0; i < count; i++) {
        final dayOffset = (i * 7 + theme.index * 3) % maxDaysAgo;
        output.add(
          AnonymizedConversationRecord(
            id: 'demo_${idCounter++}',
            theme: theme,
            ministryGroupId: ministryGroupId,
            ageBand: ageBand,
            recordedAt: now.subtract(Duration(days: dayOffset)),
            isDemo: true,
          ),
        );
      }
    }

    // Ensure every theme clears k=10 at the broadest levels.
    const themes = PastoralThemeCategory.values;
    const groups = [
      'st_marys_youth',
      'parish_confirmation',
      'campus_ministry',
    ];
    const bands = ['High School', 'Middle School', 'Young Adult'];

    for (final theme in themes) {
      // 18 records per theme across groups/bands → 180 total, 18+ per theme.
      for (var g = 0; g < groups.length; g++) {
        addRecords(
          theme: theme,
          count: 6,
          ministryGroupId: groups[g],
          ageBand: bands[g],
          maxDaysAgo: 120,
        );
      }
    }

    // Extra recent volume for 30-day roll-up demos.
    for (var i = 0; i < 40; i++) {
      output.add(
        AnonymizedConversationRecord(
          id: 'demo_recent_$i',
          theme: themes[i % themes.length],
          ministryGroupId: groups[i % groups.length],
          ageBand: bands[i % bands.length],
          recordedAt: now.subtract(Duration(days: i % 25)),
          isDemo: true,
        ),
      );
    }

    return output;
  }
}
