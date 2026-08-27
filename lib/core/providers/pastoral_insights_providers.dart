import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pastoral_insights_models.dart';
import '../insights/pastoral_insights_config.dart';
import '../services/pastoral_insights_service.dart';

final pastoralInsightsServiceProvider = Provider<PastoralInsightsService>((ref) {
  return PastoralInsightsService();
});

/// User-selected filters for the insights dashboard.
class InsightsFilterState {
  const InsightsFilterState({
    this.timeRange = InsightsTimeRange.last90Days,
    this.ministryGroupId,
    this.ageBand,
  });

  final InsightsTimeRange timeRange;
  final String? ministryGroupId;
  final String? ageBand;

  InsightsFilterState copyWith({
    InsightsTimeRange? timeRange,
    String? ministryGroupId,
    String? ageBand,
    bool clearMinistryGroup = false,
    bool clearAgeBand = false,
  }) {
    return InsightsFilterState(
      timeRange: timeRange ?? this.timeRange,
      ministryGroupId:
          clearMinistryGroup ? null : (ministryGroupId ?? this.ministryGroupId),
      ageBand: clearAgeBand ? null : (ageBand ?? this.ageBand),
    );
  }
}

class InsightsFilterNotifier extends Notifier<InsightsFilterState> {
  @override
  InsightsFilterState build() => const InsightsFilterState();

  void setTimeRange(InsightsTimeRange range) {
    state = state.copyWith(timeRange: range);
  }

  void setMinistryGroup(String? groupId) {
    if (groupId == null || groupId.isEmpty) {
      state = state.copyWith(clearMinistryGroup: true);
    } else {
      state = state.copyWith(ministryGroupId: groupId);
    }
  }

  void setAgeBand(String? band) {
    if (band == null || band.isEmpty) {
      state = state.copyWith(clearAgeBand: true);
    } else {
      state = state.copyWith(ageBand: band);
    }
  }
}

final insightsFilterProvider =
    NotifierProvider<InsightsFilterNotifier, InsightsFilterState>(
  InsightsFilterNotifier.new,
);

final insightsAggregationProvider = Provider<InsightsAggregationResult>((ref) {
  final filters = ref.watch(insightsFilterProvider);
  final service = ref.watch(pastoralInsightsServiceProvider);
  final records = service.loadRecords();

  return service.aggregate(
    records: records,
    selectedTimeRange: filters.timeRange,
    ministryGroupId: filters.ministryGroupId,
    ageBand: filters.ageBand,
  );
});

final insightsDemoModeProvider = Provider<bool>((ref) {
  return PastoralInsightsConfig.useDemoDataOnly;
});

final insightsMenuEnabledProvider = Provider<bool>((ref) {
  return PastoralInsightsConfig.insightsMenuEnabled;
});
