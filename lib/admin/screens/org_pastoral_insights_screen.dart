import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/insights/pastoral_insights_config.dart';
import '../../core/providers/pastoral_insights_providers.dart';
import '../../models/pastoral_insights_models.dart';
import '../../widgets/pastoral_insights/pastoral_theme_bar.dart';
import '../../widgets/group_brand_mark.dart';
import '../config/admin_config.dart';
import '../providers/admin_insights_providers.dart';
import '../providers/admin_providers.dart';

/// Organization-scoped Pastoral Insights — anonymized aggregates only.
class OrgPastoralInsightsScreen extends ConsumerWidget {
  const OrgPastoralInsightsScreen({
    super.key,
    required this.orgId,
  });

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgAsync = ref.watch(organizationProvider(orgId));
    final filters = ref.watch(orgInsightsFilterProvider(orgId));
    final result = ref.watch(orgInsightsAggregationProvider(orgId));
    final isDemo = ref.watch(orgInsightsDemoModeProvider(orgId));
    final groupLabels = ref.watch(organizationGroupLabelsProvider(orgId));
    final ageBands = ref.watch(organizationAgeBandsProvider(orgId));

    return orgAsync.when(
      data: (org) => Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (org != null) ...[
                GroupBrandMark(
                  groupName: org.name,
                  logoUrl: org.resolvedLogoUrl,
                  orgId: orgId,
                  size: 32,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(org?.name ?? 'Pastoral Insights'),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (isDemo) _DemoBanner(),
            if (isDemo) const SizedBox(height: 16),
            _PrivacyNoticeCard(),
            const SizedBox(height: 12),
            Text(
              AdminConfig.insightsScopeNotice,
              style: TextStyle(color: Colors.grey.shade700, height: 1.45),
            ),
            const SizedBox(height: 20),
            _FilterSection(
              orgId: orgId,
              filters: filters,
              groupLabels: groupLabels,
              ageBands: ageBands.isNotEmpty
                  ? ageBands
                  : PastoralInsightsConfig.demoAgeBands,
            ),
            const SizedBox(height: 20),
            _AggregationStatusCard(result: result),
            const SizedBox(height: 24),
            if (result.insufficientData)
              _InsufficientDataCard(threshold: result.threshold)
            else
              _ThemeResultsSection(result: result),
          ],
        ),
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Pastoral Insights')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Pastoral Insights')),
        body: Center(child: Text('$e')),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, color: AppColors.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              PastoralInsightsConfig.demoDataNotice,
              style: TextStyle(height: 1.45, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.parchment,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline,
              color: AppColors.primaryMaroon.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${PastoralInsightsConfig.privacyNotice}\n\n${AdminConfig.privacyNotice}',
                style: const TextStyle(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends ConsumerWidget {
  const _FilterSection({
    required this.orgId,
    required this.filters,
    required this.groupLabels,
    required this.ageBands,
  });

  final String orgId;
  final InsightsFilterState filters;
  final Map<String, String> groupLabels;
  final List<String> ageBands;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterNotifier = ref.read(orgInsightsFilterProvider(orgId).notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<InsightsTimeRange>(
              value: filters.timeRange,
              decoration: const InputDecoration(
                labelText: 'Time range',
                border: OutlineInputBorder(),
              ),
              items: InsightsTimeRange.values
                  .map(
                    (range) => DropdownMenuItem(
                      value: range,
                      child: Text(range.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  filterNotifier.update((s) => s.copyWith(timeRange: value));
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: filters.ministryGroupId,
              decoration: const InputDecoration(
                labelText: 'Group (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All groups'),
                ),
                ...groupLabels.entries.map(
                  (entry) => DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                ),
              ],
              onChanged: (groupId) {
                if (groupId == null || groupId.isEmpty) {
                  filterNotifier.update((s) => s.copyWith(clearMinistryGroup: true));
                } else {
                  filterNotifier.update((s) => s.copyWith(ministryGroupId: groupId));
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: filters.ageBand,
              decoration: const InputDecoration(
                labelText: 'Age band (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All age bands'),
                ),
                ...ageBands.map(
                  (band) => DropdownMenuItem<String?>(
                    value: band,
                    child: Text(band),
                  ),
                ),
              ],
              onChanged: (band) {
                if (band == null || band.isEmpty) {
                  filterNotifier.update((s) => s.copyWith(clearAgeBand: true));
                } else {
                  filterNotifier.update((s) => s.copyWith(ageBand: band));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AggregationStatusCard extends StatelessWidget {
  const _AggregationStatusCard({required this.result});

  final InsightsAggregationResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.parchmentDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aggregation level',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              result.levelDescription,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
            ),
            if (result.rolledUpFromSpecificFilter) ...[
              const SizedBox(height: 8),
              Text(
                'A broader view is shown because the selected filter did not '
                'meet the minimum of ${result.threshold} conversations needed '
                'to protect anonymity.',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (!result.insufficientData) ...[
              const SizedBox(height: 12),
              Text(
                'Pool size: ${result.poolSize} anonymized conversations · '
                'Minimum per theme: ${result.threshold}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsufficientDataCard extends StatelessWidget {
  const _InsufficientDataCard({required this.threshold});

  final int threshold;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.shield_outlined,
              size: 48,
              color: AppColors.primaryMaroon.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Insufficient data to protect anonymity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'No aggregation level reached the minimum of $threshold '
              'conversations with themes above the threshold.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeResultsSection extends StatelessWidget {
  const _ThemeResultsSection({required this.result});

  final InsightsAggregationResult result;

  @override
  Widget build(BuildContext context) {
    final maxCount = result.themeCounts.isEmpty
        ? 0
        : result.themeCounts.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top pastoral themes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryMaroon,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Only themes with at least ${result.threshold} conversations are shown.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final entry in result.themeCounts)
                  PastoralThemeBar(entry: entry, maxCount: maxCount),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
