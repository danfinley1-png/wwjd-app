import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../core/insights/pastoral_insights_config.dart';
import '../core/providers/pastoral_insights_providers.dart';
import '../models/pastoral_insights_models.dart';
import '../widgets/pastoral_insights/pastoral_theme_bar.dart';

/// Read-only anonymized pastoral insights for ministry leaders (Phase 1 demo).
class MinistryInsightsScreen extends ConsumerWidget {
  const MinistryInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(insightsFilterProvider);
    final result = ref.watch(insightsAggregationProvider);
    final isDemo = ref.watch(insightsDemoModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pastoral Insights'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _DemoBanner(visible: isDemo),
          const SizedBox(height: 16),
          _PrivacyNoticeCard(),
          const SizedBox(height: 20),
          _FilterSection(filters: filters, ref: ref),
          const SizedBox(height: 20),
          _AggregationStatusCard(result: result),
          const SizedBox(height: 24),
          if (result.insufficientData)
            _InsufficientDataCard(threshold: result.threshold)
          else
            _ThemeResultsSection(result: result),
        ],
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo Data',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryMaroon,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  PastoralInsightsConfig.demoDataNotice,
                  style: TextStyle(
                    height: 1.45,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
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
                PastoralInsightsConfig.privacyNotice,
                style: const TextStyle(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.filters,
    required this.ref,
  });

  final InsightsFilterState filters;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(insightsFilterProvider.notifier);

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
                if (value != null) notifier.setTimeRange(value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: filters.ministryGroupId,
              decoration: const InputDecoration(
                labelText: 'Ministry group (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All ministry groups'),
                ),
                ...PastoralInsightsConfig.demoMinistryGroups.entries.map(
                  (entry) => DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                ),
              ],
              onChanged: notifier.setMinistryGroup,
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
                ...PastoralInsightsConfig.demoAgeBands.map(
                  (band) => DropdownMenuItem<String?>(
                    value: band,
                    child: Text(band),
                  ),
                ),
              ],
              onChanged: notifier.setAgeBand,
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
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
              'conversations with themes above the threshold. Individual '
              'questions remain private.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.5,
              ),
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
        : result.themeCounts.map((e) => e.count).reduce(
              (a, b) => a > b ? a : b,
            );

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
