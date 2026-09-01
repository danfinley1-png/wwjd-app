import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/service_hours.dart';
import '../providers/admin_providers.dart';
import 'edit_service_project_screen.dart';

/// Lists service projects for one organization (Admin).
class OrgServiceProjectsPanel extends ConsumerWidget {
  const OrgServiceProjectsPanel({
    super.key,
    required this.orgId,
    required this.organizationName,
  });

  final String orgId;
  final String organizationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isOrganizationAdminProvider(orgId));
    final projectsAsync = ref.watch(organizationServiceProjectsProvider(orgId));
    final groups =
        ref.watch(organizationGroupsProvider(orgId)).valueOrNull ?? const [];
    final groupNames = {for (final g in groups) g.id: g.name};

    return projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load service projects: $e'),
          ),
        ),
        data: (projects) {
          final live = projects
              .where(
                (p) =>
                    !p.isMemberProposed ||
                    p.proposalStatus == ServiceProject.proposalApproved,
              )
              .toList();
          void openCreate() {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditServiceProjectScreen(
                  orgId: orgId,
                  organizationName: organizationName,
                ),
              ),
            );
          }
          if (live.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(
                  'Service projects for $organizationName. Members will log '
                  'hours later — this screen only defines the projects.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: openCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Create project'),
                  ),
                ],
                const SizedBox(height: 16),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No service projects yet. Create an Active project and '
                      'assign it to the organization or to selected groups.',
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: live.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Service projects for $organizationName. Hours logging and '
                      'approvals are not on this screen.',
                      style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: openCreate,
                        icon: const Icon(Icons.add),
                        label: const Text('Create project'),
                      ),
                    ],
                  ],
                );
              }
              final project = live[index - 1];
              return Card(
                child: ListTile(
                  leading: Icon(
                    project.isActive
                        ? Icons.volunteer_activism_outlined
                        : Icons.pause_circle_outline,
                  ),
                  title: Text(project.title),
                  subtitle: Text(_subtitle(project, groupNames)),
                  trailing: isAdmin ? const Icon(Icons.chevron_right) : null,
                  onTap: isAdmin
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditServiceProjectScreen(
                                orgId: orgId,
                                organizationName: organizationName,
                                existing: project,
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              );
            },
          );
        },
    );
  }

  String _subtitle(ServiceProject project, Map<String, String> groupNames) {
    final assignment = project.isOrgWide
        ? 'Whole organization'
        : project.assignedGroupIds
            .map((id) => groupNames[id] ?? 'Group')
            .join(', ');
    final mode = project.requiresApproval ? 'Requires approval' : 'Self-reported';
    final status = project.isActive ? 'Active' : 'Inactive';
    final origin = project.isMemberProposed ? 'Member-proposed' : 'Admin-created';
    return '$status · $mode · $assignment · $origin';
  }
}
