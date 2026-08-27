import '../../models/pastoral_insights_models.dart';
import '../../models/pastoral_theme.dart';
import '../insights/pastoral_insights_config.dart';
import '../insights/pastoral_insights_demo_data.dart';

/// Aggregates anonymized conversation themes with k-anonymity and roll-up.
class PastoralInsightsService {
  PastoralInsightsService();

  int get threshold => PastoralInsightsConfig.kAnonymityThreshold;

  /// Returns anonymized records for aggregation.
  ///
  /// Phase 1 demo: synthetic data. When [organizationId] is set and live data
  /// exists, only that organization's records are returned.
  List<AnonymizedConversationRecord> loadRecords({
    DateTime? now,
    String? organizationId,
  }) {
    if (PastoralInsightsConfig.useDemoDataOnly) {
      return PastoralInsightsDemoData.records(now: now);
    }
    // Future: read `insightsRecords` filtered by organizationId.
    return PastoralInsightsDemoData.records(now: now);
  }

  /// Resolves a ministry group label for aggregation descriptions.
  String? groupLabelFor({
    required String? ministryGroupId,
    Map<String, String> groupLabels = const {},
  }) {
    if (ministryGroupId == null) return null;
    return groupLabels[ministryGroupId] ??
        PastoralInsightsConfig.demoMinistryGroups[ministryGroupId];
  }

  InsightsAggregationResult aggregate({
    required List<AnonymizedConversationRecord> records,
    InsightsTimeRange selectedTimeRange = InsightsTimeRange.last90Days,
    String? ministryGroupId,
    String? ageBand,
    DateTime? now,
    Map<String, String> groupLabels = const {},
  }) {
    final referenceNow = now ?? DateTime.now();
    final isDemo = records.isEmpty || records.every((r) => r.isDemo);
    final rollUpChain = _buildRollUpChain(
      selectedTimeRange: selectedTimeRange,
      ministryGroupId: ministryGroupId,
      ageBand: ageBand,
    );

    for (final filter in rollUpChain) {
      final pool = _filterRecords(
        records: records,
        filter: filter,
        now: referenceNow,
      );

      if (pool.length < threshold) continue;

      final themeCounts = _themeCountsFromPool(pool);
      final visible = themeCounts
          .where((entry) => entry.count >= threshold)
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      if (visible.isEmpty) continue;

      final rolledUp = filter.level != rollUpChain.first.level;

      final groupLabel = groupLabelFor(
        ministryGroupId: ministryGroupId,
        groupLabels: groupLabels,
      );

      return InsightsAggregationResult(
        level: filter.level,
        levelDescription: filter.level.description(
          ministryGroupLabel: groupLabel ?? ministryGroupId,
          ageBand: filter.ageBand ?? ageBand,
          timeRange: filter.timeRange,
        ),
        themeCounts: visible,
        poolSize: pool.length,
        threshold: threshold,
        isDemoData: isDemo,
        insufficientData: false,
        rolledUpFromSpecificFilter: rolledUp,
        requestedTimeRange: selectedTimeRange,
      );
    }

    return InsightsAggregationResult.insufficient(
      threshold: threshold,
      isDemoData: isDemo,
      requestedTimeRange: selectedTimeRange,
    );
  }

  List<InsightsAggregationFilter> _buildRollUpChain({
    required InsightsTimeRange selectedTimeRange,
    String? ministryGroupId,
    String? ageBand,
  }) {
    final chain = <InsightsAggregationFilter>[];

    if (ministryGroupId != null && ministryGroupId.isNotEmpty) {
      chain.add(
        InsightsAggregationFilter(
          level: InsightsAggregationLevel.specificMinistryGroupAndTimeRange,
          timeRange: selectedTimeRange,
          ministryGroupId: ministryGroupId,
        ),
      );
    }

    if (ageBand != null && ageBand.isNotEmpty) {
      chain.add(
        InsightsAggregationFilter(
          level: InsightsAggregationLevel.ageBandAndTimeRange,
          timeRange: selectedTimeRange,
          ageBand: ageBand,
        ),
      );
    }

    chain.addAll([
      InsightsAggregationFilter(
        level: InsightsAggregationLevel.allUsersAndTimeRange,
        timeRange: selectedTimeRange,
      ),
      const InsightsAggregationFilter(
        level: InsightsAggregationLevel.allUsersLast90Days,
        timeRange: InsightsTimeRange.last90Days,
      ),
      const InsightsAggregationFilter(
        level: InsightsAggregationLevel.allUsersAllTime,
        timeRange: InsightsTimeRange.allTime,
      ),
    ]);

    return chain;
  }

  List<AnonymizedConversationRecord> _filterRecords({
    required List<AnonymizedConversationRecord> records,
    required InsightsAggregationFilter filter,
    required DateTime now,
  }) {
    final cutoff = _cutoffFor(filter.timeRange, now);

    return records.where((record) {
      if (cutoff != null && record.recordedAt.isBefore(cutoff)) {
        return false;
      }
      if (filter.ministryGroupId != null &&
          record.ministryGroupId != filter.ministryGroupId) {
        return false;
      }
      if (filter.ageBand != null && record.ageBand != filter.ageBand) {
        return false;
      }
      return true;
    }).toList();
  }

  DateTime? _cutoffFor(InsightsTimeRange range, DateTime now) {
    final duration = range.duration;
    if (duration == null) return null;
    return now.subtract(duration);
  }

  List<ThemeInsightCount> _themeCountsFromPool(
    List<AnonymizedConversationRecord> pool,
  ) {
    if (pool.isEmpty) return [];

    final counts = <PastoralThemeCategory, int>{};
    for (final record in pool) {
      counts.update(record.theme, (value) => value + 1, ifAbsent: () => 1);
    }

    final total = pool.length;
    return PastoralThemeCategory.values
        .where((theme) => counts.containsKey(theme))
        .map(
          (theme) => ThemeInsightCount(
            theme: theme,
            count: counts[theme]!,
            percentage: (counts[theme]! / total) * 100,
          ),
        )
        .toList();
  }
}
