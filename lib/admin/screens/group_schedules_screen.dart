import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/group_practice_tracking.dart';
import '../../models/group_practice_instance.dart';
import '../../widgets/group_brand_mark.dart';
import '../models/ministry_group.dart';
import '../models/organization.dart';
import '../providers/admin_providers.dart';
import 'create_group_schedule_screen.dart';

/// Lists recurring group practices for a ministry group (org admin).
class GroupSchedulesScreen extends ConsumerWidget {
  const GroupSchedulesScreen({
    super.key,
    required this.orgId,
    required this.group,
    required this.organizationName,
  });

  final String orgId;
  final MinistryGroup group;
  final String organizationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isOrganizationAdminProvider(orgId));
    final schedulesAsync =
        ref.watch(organizationGroupSchedulesProvider((orgId, group.id)));
    final orgLogo = Organization.resolveLogoUrl(
      organizationLogoUrl:
          ref.watch(organizationProvider(orgId)).valueOrNull?.resolvedLogoUrl,
      fallback: group.logoUrl,
    );

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text('${group.name} schedules')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only organization administrators can manage group schedules.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GroupBrandMark(
              groupName: group.name,
              logoUrl: orgLogo,
              orgId: orgId,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${group.name} schedules'),
                  const Text(
                    'Recurring group practices',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: schedulesAsync.when(
        data: (schedules) {
          final active = schedules.where((s) => s.active).toList();
          if (active.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No group schedules yet.\n\nCreate a recurring prayer or '
                  'practice for accepted group members.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: active.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final schedule = active[index];
              final instance = GroupPracticeInstance.fromSchedule(schedule);
              final summary = GroupPracticeTracking.timesSummary(instance);

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(schedule.title),
                  subtitle: Text(
                    [
                      if (schedule.description.isNotEmpty) schedule.description,
                      summary,
                    ].join('\n'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.pause_circle_outline),
                    tooltip: 'Deactivate',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Deactivate schedule?'),
                          content: Text(
                            'Members will no longer see "${schedule.title}" '
                            'in My Gifts.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Deactivate'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      try {
                        await ref
                            .read(groupScheduleServiceProvider)
                            .deactivateSchedule(
                              orgId: orgId,
                              groupId: group.id,
                              scheduleId: schedule.id,
                            );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CreateGroupScheduleScreen(
                orgId: orgId,
                group: group,
                organizationName: organizationName,
              ),
            ),
          );
          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Group schedule created for accepted members.'),
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New schedule'),
      ),
    );
  }
}
