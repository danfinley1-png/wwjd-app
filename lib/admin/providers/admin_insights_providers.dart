import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/insights/pastoral_insights_config.dart';
import '../../core/providers/pastoral_insights_providers.dart';
import '../../models/pastoral_insights_models.dart';
import 'admin_providers.dart';

/// Per-organization insights filters (admin layer only).
final orgInsightsFilterProvider =
    StateProvider.family<InsightsFilterState, String>(
  (ref, orgId) => const InsightsFilterState(),
);

final orgInsightsAggregationProvider =
    Provider.family<InsightsAggregationResult, String>((ref, orgId) {
  final filters = ref.watch(orgInsightsFilterProvider(orgId));
  final service = ref.watch(pastoralInsightsServiceProvider);
  final groupLabels = ref.watch(organizationGroupLabelsProvider(orgId));
  final records = service.loadRecords(organizationId: orgId);

  return service.aggregate(
    records: records,
    selectedTimeRange: filters.timeRange,
    ministryGroupId: filters.ministryGroupId,
    ageBand: filters.ageBand,
    groupLabels: groupLabels,
  );
});

final orgInsightsDemoModeProvider = Provider.family<bool, String>((ref, orgId) {
  return PastoralInsightsConfig.useDemoDataOnly;
});
