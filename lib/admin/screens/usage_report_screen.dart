import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config/admin_config.dart';
import '../models/usage_report.dart';
import '../providers/admin_providers.dart';
import '../../core/analytics/usage_device_class.dart';
import '../../core/analytics/usage_section.dart';

/// Super Admin aggregate adoption and engagement report (privacy-safe).
class UsageReportScreen extends ConsumerStatefulWidget {
  const UsageReportScreen({super.key});

  @override
  ConsumerState<UsageReportScreen> createState() => _UsageReportScreenState();
}

class _UsageReportScreenState extends ConsumerState<UsageReportScreen> {
  UsageReportPeriod _period = UsageReportPeriod.days30;
  AsyncValue<UsageReport>? _report;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWhenReady());
  }

  Future<void> _loadWhenReady() async {
    final isSuperAdmin = ref.read(isSuperAdminProvider).valueOrNull ?? false;
    if (!isSuperAdmin) {
      if (!mounted) return;
      setState(() {
        _report = AsyncValue.error(
          Exception('Super Admin access required.'),
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
      final report =
          await ref.read(usageReportServiceProvider).fetchReport(_period);
      if (!mounted) return;
      setState(() => _report = AsyncValue.data(report));
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _report = AsyncValue.error(e, st));
    }
  }

  void _setPeriod(UsageReportPeriod period) {
    if (_period == period) return;
    setState(() => _period = period);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
    if (!isSuperAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Usage Report')),
        body: const Center(
          child: Text('Super Admin access required.'),
        ),
      );
    }

    final reportAsync = _report ?? const AsyncValue.loading();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Report'),
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
        error: (e, _) => Center(child: Text('Could not load report: $e')),
        data: (report) => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _PrivacyBanner(),
              const SizedBox(height: 16),
              _PeriodSelector(
                selected: _period,
                onSelected: _setPeriod,
              ),
              if (report.trackingStartedAt != null) ...[
                const SizedBox(height: 12),
                _TrackingNotice(startedAt: report.trackingStartedAt!),
              ],
              if (report.note != null) ...[
                const SizedBox(height: 12),
                _InfoBanner(text: report.note!),
              ],
              const SizedBox(height: 20),
              Text(
                'User & growth',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              _MetricGrid(
                items: [
                  _MetricTile(
                    label: 'Total registered users',
                    value: _formatCount(report.totalRegisteredUsers),
                    subtitle: report.userMetricsFromAuth
                        ? 'Firebase Auth (non-guest accounts)'
                        : 'Requires Cloud Function',
                  ),
                  _MetricTile(
                    label: 'New registrations',
                    value: _formatCount(report.newRegistrationsInPeriod),
                    subtitle: _periodLabel(_period),
                  ),
                  _MetricTile(
                    label: 'Active users (7 days)',
                    value: _formatCount(report.activeUsers7Days),
                    subtitle: 'Registered users with recent activity',
                  ),
                  _MetricTile(
                    label: 'Active users (30 days)',
                    value: _formatCount(report.activeUsers30Days),
                    subtitle: 'Registered users with recent activity',
                  ),
                  _MetricTile(
                    label: 'Guest sessions',
                    value: _formatCount(report.guestSessionsInPeriod),
                    subtitle: _engagementPeriodLabel(report),
                    fullWidth: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Engagement',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              _MetricGrid(
                items: [
                  _MetricTile(
                    label: 'Total screen time',
                    value: _formatHours(report.totalScreenTimeHours),
                    subtitle: _engagementPeriodLabel(report),
                  ),
                  _MetricTile(
                    label: 'Average session length',
                    value: _formatDuration(report.averageSessionLengthSeconds),
                    subtitle:
                        '${_formatCount(report.totalSessionCount)} sessions',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionBreakdown(report: report),
              const SizedBox(height: 20),
              _DeviceBreakdown(report: report),
              const SizedBox(height: 24),
              _DataSourcesCard(report: report),
            ],
          ),
        ),
      ),
    );
  }

  String _periodLabel(UsageReportPeriod period) => period.label;

  String _engagementPeriodLabel(UsageReport report) {
    if (report.trackingStartedAt == null) {
      return '${report.period.label} · tracking start date not set yet';
    }
    return '${report.period.label} · detailed metrics since tracking began';
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onSelected,
  });

  final UsageReportPeriod selected;
  final ValueChanged<UsageReportPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final period in UsageReportPeriod.values)
          ChoiceChip(
            label: Text(period.label),
            selected: selected == period,
            onSelected: (_) => onSelected(period),
          ),
      ],
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Colors.blueGrey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${AdminConfig.privacyNotice}\n\n'
              'This report shows aggregate counts only. You cannot open any '
              "user's conversations, reflections, or gift details from here.",
              style: const TextStyle(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingNotice extends StatelessWidget {
  const _TrackingNotice({required this.startedAt});

  final DateTime startedAt;

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat.yMMMMd().format(startedAt.toLocal());
    return _InfoBanner(
      text:
          'Detailed usage metrics (screen time, section visits, device class, '
          'and guest session volume) are recorded from $formatted onward. '
          'Registered-user totals use Firebase Auth history and may include '
          'earlier sign-ups.',
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<_MetricTile> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 720 ? 2 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: columns == 2 && !item.fullWidth
                    ? (width - 12) / 2
                    : width,
                child: item,
              ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.subtitle,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final String subtitle;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionBreakdown extends ConsumerWidget {
  const _SectionBreakdown({required this.report});

  final UsageReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.read(usageReportServiceProvider).reportSections;
    final rows = <UsageSection>[
      for (final section in sections)
        if (report.sectionViewCount(section.id) > 0) section,
    ];

    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No section visit data yet for this period.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    final totalViews =
        rows.fold<int>(0, (sum, s) => sum + report.sectionViewCount(s.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Section visits',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Share of recorded section opens in the selected period',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            for (final section in rows) ...[
              _BarRow(
                label: section.label,
                count: report.sectionViewCount(section.id),
                fraction: totalViews == 0
                    ? 0
                    : report.sectionViewCount(section.id) / totalViews,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceBreakdown extends StatelessWidget {
  const _DeviceBreakdown({required this.report});

  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Access mode (sessions)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Device class breakdown by session count',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            for (final device in UsageDeviceClass.values) ...[
              _BarRow(
                label: device.label,
                count: report.deviceSessionCount(device.id),
                fraction: report.deviceSessionShare(device.id),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.count,
    required this.fraction,
  });

  final String label;
  final int count;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text('$count · ${(fraction * 100).toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
      ],
    );
  }
}

class _DataSourcesCard extends StatelessWidget {
  const _DataSourcesCard({required this.report});

  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data sources & safeguards',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Registered users and sign-up dates: Firebase Auth (aggregate counts only)\n'
              '• Active users: Firestore lastActive timestamps (registered accounts only; no content read)\n'
              '• Screen time, sessions, section visits, device class, guest sessions: daily aggregate counters written by the app\n'
              '• No conversation text, reflection body, gift detail, or per-user spiritual history is stored in analytics or exposed here',
              style: TextStyle(height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCount(int value) => NumberFormat.decimalPattern().format(value);

String _formatHours(double hours) {
  if (hours < 1) return '${(hours * 60).round()} min';
  return '${hours.toStringAsFixed(1)} hr';
}

String _formatDuration(double seconds) {
  if (seconds < 60) return '${seconds.round()} sec';
  final minutes = seconds / 60;
  if (minutes < 60) return '${minutes.toStringAsFixed(1)} min';
  return '${(minutes / 60).toStringAsFixed(1)} hr';
}
