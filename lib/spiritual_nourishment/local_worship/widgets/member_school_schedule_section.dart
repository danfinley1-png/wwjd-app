import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/models/organization.dart';
import '../../../admin/providers/admin_providers.dart';
import '../../../admin/widgets/org_calendar_views.dart';
import '../../../core/providers/app_providers.dart';
import '../../../widgets/group_brand_mark.dart';

/// Read-only published school/organization schedule for members in user mode.
class MemberSchoolScheduleSection extends ConsumerStatefulWidget {
  const MemberSchoolScheduleSection({
    super.key,
    this.initialOrgId,
    this.onSelectOrg,
  });

  final String? initialOrgId;
  final ValueChanged<String>? onSelectOrg;

  @override
  ConsumerState<MemberSchoolScheduleSection> createState() =>
      _MemberSchoolScheduleSectionState();
}

class _MemberSchoolScheduleSectionState
    extends ConsumerState<MemberSchoolScheduleSection> {
  String? _selectedOrgId;

  @override
  void initState() {
    super.initState();
    _selectedOrgId = widget.initialOrgId;
  }

  @override
  void didUpdateWidget(MemberSchoolScheduleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOrgId != oldWidget.initialOrgId &&
        widget.initialOrgId != null) {
      _selectedOrgId = widget.initialOrgId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null || user.isAnonymous) {
      return const _ScheduleMessage(
        'Sign in with the account that joined your school to see the published '
        'schedule. This is not an administrator sign-in.',
      );
    }

    final orgsAsync = ref.watch(memberOrganizationsProvider);
    return orgsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => _ScheduleMessage('Could not load organizations: $e'),
      data: (orgs) {
        if (orgs.isEmpty) {
          return const _ScheduleMessage(
            'Join a school or organization to see the published schedule. '
            'Ask an organization administrator for an invitation.',
          );
        }
        final selectedId = _resolveSelectedOrg(orgs);
        final selectedOrg = orgs.firstWhere((org) => org.id == selectedId);
        return _ScheduleForOrg(
          orgs: orgs,
          selectedOrg: selectedOrg,
          onSelectOrg: (id) {
            setState(() => _selectedOrgId = id);
            widget.onSelectOrg?.call(id);
          },
        );
      },
    );
  }

  String _resolveSelectedOrg(List<Organization> orgs) {
    final current = _selectedOrgId;
    if (current != null && orgs.any((org) => org.id == current)) {
      return current;
    }
    return orgs.first.id;
  }
}

class _ScheduleForOrg extends ConsumerWidget {
  const _ScheduleForOrg({
    required this.orgs,
    required this.selectedOrg,
    required this.onSelectOrg,
  });

  final List<Organization> orgs;
  final Organization selectedOrg;
  final ValueChanged<String> onSelectOrg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership =
        ref.watch(organizationMembershipProvider(selectedOrg.id)).valueOrNull;
    final groupKey = (membership?.groupIds ?? const <String>[])
        .toSet()
        .toList()
      ..sort();
    final scheduleAsync = ref.watch(
      memberOrgCalendarScheduleProvider(
        OrgMemberCalendarKey(
          orgId: selectedOrg.id,
          groupKey: groupKey.join(','),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GroupBrandMark(
              groupName: selectedOrg.name,
              logoUrl: selectedOrg.resolvedLogoUrl,
              orgId: selectedOrg.id,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedOrg.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'School schedule',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Published by your organization administrator. Title, When, location, '
          'and notes are read-only here.',
          style: TextStyle(height: 1.45, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 12),
        if (orgs.length > 1) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final org in orgs)
                ChoiceChip(
                  avatar: GroupBrandMark(
                    groupName: org.name,
                    logoUrl: org.resolvedLogoUrl,
                    orgId: org.id,
                    size: 24,
                  ),
                  label: Text(org.name),
                  selected: org.id == selectedOrg.id,
                  onSelected: (_) => onSelectOrg(org.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        scheduleAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _ScheduleMessage(
            'Could not load the school schedule: $e',
          ),
          data: (schedule) {
            final visible = schedule.isVisibleToMember(
              membership?.groupIds ?? const [],
            );
            return OrgScheduleReadOnlyList(
              rows: visible ? schedule.completeRows : const [],
              emptyMessage: 'No school schedule has been published yet.',
            );
          },
        ),
      ],
    );
  }
}

class _ScheduleMessage extends StatelessWidget {
  const _ScheduleMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: TextStyle(height: 1.45, color: Colors.grey.shade800),
        ),
      ),
    );
  }
}
