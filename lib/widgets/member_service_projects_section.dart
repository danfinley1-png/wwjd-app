import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../admin/models/organization.dart';
import '../admin/models/service_hours.dart';
import '../admin/providers/admin_providers.dart';
import '../core/app_colors.dart';
import '../core/gift_list_filter.dart';
import '../core/models/shareable_group.dart';
import '../core/providers/app_providers.dart';
import '../screens/member_service_project_hours_screen.dart';
import '../screens/propose_service_project_screen.dart';

/// Member-facing Active service projects on Sharing My Gifts.
class MemberServiceProjectsSection extends ConsumerWidget {
  const MemberServiceProjectsSection({
    super.key,
    required this.filterKind,
    this.filterOrgId,
    this.filterGroupId,
    this.showHeader = true,
  });

  final GiftFilterKind filterKind;
  final String? filterOrgId;
  final String? filterGroupId;
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filterKind == GiftFilterKind.personal) {
      return const SizedBox.shrink();
    }

    final orgsAsync = ref.watch(memberOrganizationsProvider);
    final orgs = orgsAsync.valueOrNull ?? const <Organization>[];
    if (orgsAsync.hasValue && orgs.isEmpty) {
      return const SizedBox.shrink();
    }

    final groups =
        ref.watch(profileGroupMembershipsProvider).valueOrNull ??
            const <ShareableGroup>[];
    final projectsAsync = ref.watch(memberAssignedServiceProjectsProvider);

    return projectsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              const _Header(),
              const SizedBox(height: 8),
            ],
            const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              const _Header(),
              const SizedBox(height: 8),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service projects could not be loaded yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref
                          .invalidate(memberAssignedServiceProjectsProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      data: (projects) {
        final visible = projects.where((project) {
          return _matchesFilter(
            project,
            groups: groups,
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                const _Header(),
                const SizedBox(height: 8),
              ],
              if (visible.isEmpty)
                const Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No active service projects are assigned to your '
                      'organization or groups right now.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...visible.map(
                  (project) => _MemberServiceProjectCard(
                    project: project,
                    audienceLabel: _audienceLabel(project, orgs, groups),
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: orgs.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ProposeServiceProjectScreen(
                                initialOrgId: filterOrgId ?? orgs.first.id,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Propose a service project'),
                ),
              ),
              const SizedBox(height: 20),
              const _ProposalsHeader(),
              const SizedBox(height: 8),
              _MemberProposalsList(
                filterKind: filterKind,
                filterOrgId: filterOrgId,
                filterGroupId: filterGroupId,
              ),
            ],
          ),
        );
      },
    );
  }

  bool _matchesFilter(
    ServiceProject project, {
    required List<ShareableGroup> groups,
  }) {
    switch (filterKind) {
      case GiftFilterKind.all:
        return true;
      case GiftFilterKind.personal:
        return false;
      case GiftFilterKind.organization:
        return filterOrgId != null &&
            filterOrgId!.isNotEmpty &&
            project.orgId == filterOrgId;
      case GiftFilterKind.group:
        if (filterGroupId == null || filterGroupId!.isEmpty) return false;
        ShareableGroup? group;
        for (final candidate in groups) {
          if (candidate.groupId == filterGroupId) {
            group = candidate;
            break;
          }
        }
        if (project.isOrgWide) {
          return group != null && project.orgId == group.organizationId;
        }
        return project.assignedGroupIds.contains(filterGroupId);
    }
  }

  static String _orgName(String orgId, List<Organization> orgs) {
    for (final org in orgs) {
      if (org.id == orgId) return org.name;
    }
    return 'Organization';
  }

  static String _audienceLabel(
    ServiceProject project,
    List<Organization> orgs,
    List<ShareableGroup> groups,
  ) {
    final orgName = _orgName(project.orgId, orgs);
    if (project.isOrgWide) return orgName;
    final names = <String>[];
    for (final id in project.assignedGroupIds) {
      for (final group in groups) {
        if (group.groupId == id && group.groupName.trim().isNotEmpty) {
          names.add(group.groupName.trim());
          break;
        }
      }
    }
    if (names.isEmpty) return orgName;
    return '$orgName · ${names.join(', ')}';
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.volunteer_activism_outlined,
            color: AppColors.primaryMaroon, size: 22),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Service projects',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Assigned to your organization or groups',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberServiceProjectCard extends StatelessWidget {
  const _MemberServiceProjectCard({
    required this.project,
    required this.audienceLabel,
  });

  final ServiceProject project;
  final String audienceLabel;

  @override
  Widget build(BuildContext context) {
    final window = _windowLabel(project);
    final location = project.location.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => MemberServiceProjectHoursScreen(
                project: project,
              ),
            ),
          );
        },
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              audienceLabel,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
            if (window.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                window,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Mode: ${project.modeDisplayLabel}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MemberServiceProjectHoursScreen(
                        project: project,
                      ),
                    ),
                  );
                },
                child: const Text('Log hours'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  static String _windowLabel(ServiceProject project) {
    final start = project.startDate;
    final end = project.endDate;
    if (start == null && end == null) return '';
    final fmt = DateFormat.yMMMd();
    if (start != null && end != null) {
      return '${fmt.format(start)} – ${fmt.format(end)}';
    }
    if (start != null) return 'Starts ${fmt.format(start)}';
    return 'Through ${fmt.format(end!)}';
  }
}

class _ProposalsHeader extends StatelessWidget {
  const _ProposalsHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.outgoing_mail, color: AppColors.primaryMaroon, size: 22),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your proposals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Submitted, returned, and rejected stay private to you',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberProposalsList extends ConsumerWidget {
  const _MemberProposalsList({
    required this.filterKind,
    this.filterOrgId,
    this.filterGroupId,
  });

  final GiftFilterKind filterKind;
  final String? filterOrgId;
  final String? filterGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalsAsync = ref.watch(memberProposedServiceProjectsProvider);
    final groups =
        ref.watch(profileGroupMembershipsProvider).valueOrNull ??
            const <ShareableGroup>[];

    return proposalsAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (err, stack) {
        debugPrint('memberProposedServiceProjectsProvider: $err\n$stack');
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your proposals could not be loaded yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(memberProposedServiceProjectsProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      },
      data: (proposals) {
        final visible = proposals.where((project) {
          if (project.proposalStatus == ServiceProject.proposalApproved) {
            return false;
          }
          switch (filterKind) {
            case GiftFilterKind.all:
              return true;
            case GiftFilterKind.personal:
              return false;
            case GiftFilterKind.organization:
              return filterOrgId != null && project.orgId == filterOrgId;
            case GiftFilterKind.group:
              if (filterGroupId == null) return false;
              ShareableGroup? group;
              for (final candidate in groups) {
                if (candidate.groupId == filterGroupId) {
                  group = candidate;
                  break;
                }
              }
              if (project.isOrgWide) {
                return group != null && project.orgId == group.organizationId;
              }
              return project.assignedGroupIds.contains(filterGroupId);
          }
        }).toList();

        if (visible.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No proposals in review. Propose a project when your group '
                'has a new service need.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final project in visible)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(project.title),
                  subtitle: Text(_proposalSubtitle(project)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ProposeServiceProjectScreen(
                          existing: project,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  String _proposalSubtitle(ServiceProject project) {
    final reason = project.rejectionReason.trim();
    if (project.proposalStatus == ServiceProject.proposalRejected &&
        reason.isNotEmpty) {
      return '${project.proposalStatusLabel} · $reason';
    }
    final note = project.proposalNote.trim();
    if (project.proposalStatus == ServiceProject.proposalReturned &&
        note.isNotEmpty) {
      return '${project.proposalStatusLabel} · $note';
    }
    return project.proposalStatusLabel;
  }
}
