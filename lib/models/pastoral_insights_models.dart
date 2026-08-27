import 'pastoral_theme.dart';

/// Selected time window for insights queries.
enum InsightsTimeRange {
  last30Days,
  last90Days,
  lastYear,
  allTime,
}

extension InsightsTimeRangeLabels on InsightsTimeRange {
  String get label {
    switch (this) {
      case InsightsTimeRange.last30Days:
        return 'Last 30 days';
      case InsightsTimeRange.last90Days:
        return 'Last 90 days';
      case InsightsTimeRange.lastYear:
        return 'Last year';
      case InsightsTimeRange.allTime:
        return 'All time';
    }
  }

  Duration? get duration {
    switch (this) {
      case InsightsTimeRange.last30Days:
        return const Duration(days: 30);
      case InsightsTimeRange.last90Days:
        return const Duration(days: 90);
      case InsightsTimeRange.lastYear:
        return const Duration(days: 365);
      case InsightsTimeRange.allTime:
        return null;
    }
  }
}

/// Roll-up level from most specific to broadest.
enum InsightsAggregationLevel {
  specificMinistryGroupAndTimeRange,
  ageBandAndTimeRange,
  allUsersAndTimeRange,
  allUsersLast90Days,
  allUsersAllTime,
  insufficientData,
}

extension InsightsAggregationLevelLabels on InsightsAggregationLevel {
  String description({
    String? ministryGroupLabel,
    String? ageBand,
    InsightsTimeRange? timeRange,
  }) {
    switch (this) {
      case InsightsAggregationLevel.specificMinistryGroupAndTimeRange:
        return 'Ministry group: ${ministryGroupLabel ?? 'Selected group'} · ${timeRange?.label ?? 'selected period'}';
      case InsightsAggregationLevel.ageBandAndTimeRange:
        return 'Age band: ${ageBand ?? 'Selected band'} · ${timeRange?.label ?? 'selected period'}';
      case InsightsAggregationLevel.allUsersAndTimeRange:
        return 'All users · ${timeRange?.label ?? 'selected period'}';
      case InsightsAggregationLevel.allUsersLast90Days:
        return 'All users · Last 90 days';
      case InsightsAggregationLevel.allUsersAllTime:
        return 'All users · All time';
      case InsightsAggregationLevel.insufficientData:
        return 'Insufficient data to protect anonymity';
    }
  }
}

/// Synthetic anonymized record — never contains user identifiers or message text.
class AnonymizedConversationRecord {
  const AnonymizedConversationRecord({
    required this.id,
    required this.theme,
    required this.recordedAt,
    this.organizationId,
    this.ministryGroupId,
    this.ageBand,
    this.isDemo = false,
  });

  final String id;
  final PastoralThemeCategory theme;
  final DateTime recordedAt;
  final String? organizationId;
  final String? ministryGroupId;
  final String? ageBand;
  final bool isDemo;
}

/// Count for one theme within an aggregation result.
class ThemeInsightCount {
  const ThemeInsightCount({
    required this.theme,
    required this.count,
    required this.percentage,
  });

  final PastoralThemeCategory theme;
  final int count;
  final double percentage;
}

/// Result of the theme aggregation engine.
class InsightsAggregationResult {
  const InsightsAggregationResult({
    required this.level,
    required this.levelDescription,
    required this.themeCounts,
    required this.poolSize,
    required this.threshold,
    required this.isDemoData,
    required this.insufficientData,
    required this.rolledUpFromSpecificFilter,
    this.requestedTimeRange,
  });

  final InsightsAggregationLevel level;
  final String levelDescription;
  final List<ThemeInsightCount> themeCounts;
  final int poolSize;
  final int threshold;
  final bool isDemoData;
  final bool insufficientData;
  final bool rolledUpFromSpecificFilter;
  final InsightsTimeRange? requestedTimeRange;

  factory InsightsAggregationResult.insufficient({
    required int threshold,
    required bool isDemoData,
    InsightsTimeRange? requestedTimeRange,
  }) {
    return InsightsAggregationResult(
      level: InsightsAggregationLevel.insufficientData,
      levelDescription: InsightsAggregationLevel.insufficientData.description(),
      themeCounts: const [],
      poolSize: 0,
      threshold: threshold,
      isDemoData: isDemoData,
      insufficientData: true,
      rolledUpFromSpecificFilter: false,
      requestedTimeRange: requestedTimeRange,
    );
  }

  bool get hasVisibleThemes => themeCounts.isNotEmpty && !insufficientData;
}

/// Internal filter step for roll-up attempts.
class InsightsAggregationFilter {
  const InsightsAggregationFilter({
    required this.level,
    required this.timeRange,
    this.ministryGroupId,
    this.ageBand,
  });

  final InsightsAggregationLevel level;
  final InsightsTimeRange timeRange;
  final String? ministryGroupId;
  final String? ageBand;
}
