import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/insights/pastoral_insights_config.dart';
import '../../core/insights/question_theme_aggregator.dart';
import '../../models/pastoral_theme.dart';
import '../config/admin_config.dart';
import '../models/question_theme_report.dart';
import '../providers/admin_providers.dart';

/// Admin-only anonymized question theme report.
///
/// Overall Admin: platform volume. Org Admin: that organization only.
class QuestionThemeReportScreen extends ConsumerStatefulWidget {
  const QuestionThemeReportScreen({super.key, this.orgId});

  final String? orgId;

  @override
  ConsumerState<QuestionThemeReportScreen> createState() =>
      _QuestionThemeReportScreenState();
}

class _QuestionThemeReportScreenState
    extends ConsumerState<QuestionThemeReportScreen> {
  int? _periodDays = 90;
  String? _groupId;
  QuestionThemeSource? _source;
  bool _splitSources = false;
  bool _syntheticPreview = false;
  AsyncValue<QuestionThemeReport>? _report;

  bool get _orgScoped => widget.orgId != null && widget.orgId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWhenReady());
  }

  Future<void> _loadWhenReady() async {
    final isSuper = ref.read(isSuperAdminProvider).valueOrNull ?? false;
    if (!_orgScoped && !isSuper) {
      if (!mounted) return;
      setState(() {
        _report = AsyncValue.error(
          Exception('Overall Admin or Organization Admin access required.'),
          StackTrace.current,
        );
      });
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _report = const AsyncValue.loading());
    try {
      final report = await ref.read(questionThemeReportServiceProvider).fetchReport(
            periodDays: _periodDays,
            organizationId: widget.orgId,
            groupId: _groupId,
            source: _source,
            syntheticPreview: _syntheticPreview,
          );
      if (!mounted) return;
      setState(() => _report = AsyncValue.data(report));
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _report = AsyncValue.error(e, st));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = _report ?? const AsyncValue.loading();
    return Scaffold(
      appBar: AppBar(
        title: Text(_orgScoped ? 'Question themes' : 'Question themes (all)'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: reportAsync.isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$e'.replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        ),
        data: _buildBody,
      ),
    );
  }

  Widget _buildBody(QuestionThemeReport report) {
    final groups = _orgScoped
        ? ref.watch(organizationGroupsProvider(widget.orgId!)).valueOrNull ??
            const []
        : const [];
    final agg = report.aggregation;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (report.isSynthetic) _SyntheticBanner(),
        if (report.isSynthetic) const SizedBox(height: 12),
        _NoticeCard(text: PastoralInsightsConfig.privacyNotice),
        const SizedBox(height: 12),
        _NoticeCard(text: PastoralInsightsConfig.suppressionNotice),
        if (_orgScoped) ...[
          const SizedBox(height: 12),
          Text(
            AdminConfig.insightsScopeNotice,
            style: TextStyle(color: Colors.grey.shade700, height: 1.45),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in const [
              (30, 'Last 30 days'),
              (90, 'Last 90 days'),
              (365, 'Last year'),
              (null, 'All time'),
            ])
              ChoiceChip(
                label: Text(option.$2),
                selected: _periodDays == option.$1,
                onSelected: (_) {
                  setState(() => _periodDays = option.$1);
                  _load();
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All sources'),
              selected: _source == null,
              onSelected: (_) {
                setState(() => _source = null);
                _load();
              },
            ),
            FilterChip(
              label: const Text("Seeking God's Wisdom"),
              selected: _source == QuestionThemeSource.seekingGodsWisdom,
              onSelected: (_) {
                setState(
                  () => _source = QuestionThemeSource.seekingGodsWisdom,
                );
                _load();
              },
            ),
            FilterChip(
              label: const Text('Walk Together'),
              selected: _source == QuestionThemeSource.walkTogether,
              onSelected: (_) {
                setState(() => _source = QuestionThemeSource.walkTogether);
                _load();
              },
            ),
            FilterChip(
              label: const Text('Split sources in table'),
              selected: _splitSources,
              onSelected: (selected) {
                setState(() => _splitSources = selected);
              },
            ),
          ],
        ),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _groupId,
            decoration: const InputDecoration(
              labelText: 'Group',
              border: OutlineInputBorder(),
              helperText:
                  'Tiny group+theme cells roll up to the organization.',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All groups in this organization'),
              ),
              for (final group in groups)
                DropdownMenuItem<String?>(
                  value: group.id,
                  child: Text(group.name),
                ),
            ],
            onChanged: (value) {
              setState(() => _groupId = value);
              _load();
            },
          ),
        ],
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Labeled synthetic preview'),
          subtitle: const Text(
            'Demonstration data only — not live questions.',
          ),
          value: _syntheticPreview,
          onChanged: (value) {
            setState(() => _syntheticPreview = value);
            _load();
          },
        ),
        if (agg.rolledUpFromGroup)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'This group did not have 8 distinct people in the period, '
              'so counts rolled up to the organization.',
              style: TextStyle(color: Colors.grey.shade800, height: 1.45),
            ),
          ),
        if (agg.insufficientVolume) ...[
          _InsufficientCard(threshold: agg.threshold),
        ] else if (agg.rolledUpToAllThemes) ...[
          _AllThemesCard(aggregation: agg),
        ] else ...[
          _ThemeTable(
            aggregation: agg,
            splitSources: _splitSources && _source == null,
            showTrend: _periodDays != null,
          ),
        ],
        const SizedBox(height: 16),
        _SourceTotals(aggregation: agg),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Text(text, style: TextStyle(height: 1.45, color: Colors.grey.shade800)),
    );
  }
}

class _SyntheticBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, color: AppColors.gold),
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

class _InsufficientCard extends StatelessWidget {
  const _InsufficientCard({required this.threshold});
  final int threshold;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Insufficient volume to protect anonymity. '
          'A cell needs at least $threshold distinct people before a number is shown.',
          style: const TextStyle(height: 1.45),
        ),
      ),
    );
  }
}

class _AllThemesCard extends StatelessWidget {
  const _AllThemesCard({
    required this.aggregation,
  });

  final QuestionThemeAggregation aggregation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('All themes'),
        subtitle: const Text(
          'No single theme reached 8 distinct people, so only the combined count is shown.',
        ),
        trailing: Text(
          '${aggregation.allThemesDistinctUsers}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
    );
  }
}

class _ThemeTable extends StatelessWidget {
  const _ThemeTable({
    required this.aggregation,
    required this.splitSources,
    required this.showTrend,
  });

  final QuestionThemeAggregation aggregation;
  final bool splitSources;
  final bool showTrend;

  String _cell(bool suppressed, int? value) {
    if (suppressed || value == null) {
      return QuestionThemeAggregation.insufficientLabel;
    }
    return '$value';
  }

  String _trend(QuestionThemeCell cell) {
    if (cell.suppressed || cell.previousSuppressed) {
      return QuestionThemeAggregation.insufficientLabel;
    }
    final delta = (cell.distinctUsers ?? 0) - (cell.previousDistinctUsers ?? 0);
    if (delta == 0) return 'No change';
    if (delta > 0) return '+$delta';
    return '$delta';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Theme')),
          const DataColumn(label: Text('People')),
          if (showTrend) const DataColumn(label: Text('vs prior period')),
          if (splitSources) const DataColumn(label: Text("Seeking God's Wisdom")),
          if (splitSources) const DataColumn(label: Text('Walk Together')),
        ],
        rows: [
          for (final cell in aggregation.cells)
            DataRow(
              cells: [
                DataCell(Text(cell.theme.label)),
                DataCell(Text(_cell(cell.suppressed, cell.distinctUsers))),
                if (showTrend) DataCell(Text(_trend(cell))),
                if (splitSources)
                  DataCell(
                    Text(
                      _cell(
                        cell.seekingWisdomSuppressed,
                        cell.seekingWisdomUsers,
                      ),
                    ),
                  ),
                if (splitSources)
                  DataCell(
                    Text(
                      _cell(
                        cell.walkTogetherSuppressed,
                        cell.walkTogetherUsers,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SourceTotals extends StatelessWidget {
  const _SourceTotals({required this.aggregation});
  final QuestionThemeAggregation aggregation;

  String _label(bool suppressed, int? value) {
    if (suppressed || value == null) {
      return QuestionThemeAggregation.insufficientLabel;
    }
    return '$value distinct people';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'By source',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Seeking God's Wisdom"),
          trailing: Text(
            _label(
              aggregation.seekingWisdomSuppressed,
              aggregation.seekingWisdomDistinctUsers,
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Walk Together'),
          trailing: Text(
            _label(
              aggregation.walkTogetherSuppressed,
              aggregation.walkTogetherDistinctUsers,
            ),
          ),
        ),
      ],
    );
  }
}
