import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ministry_group.dart';
import '../models/organization.dart';
import '../providers/admin_providers.dart';
import '../../widgets/group_brand_mark.dart';
import 'group_members_screen.dart';

/// Super Admin view of ministry groups across all organizations.
class PlatformGroupsScreen extends ConsumerWidget {
  const PlatformGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(allPlatformGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All groups'),
        centerTitle: true,
      ),
      body: groupsAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No groups have been created yet. Groups live inside organizations — '
                  'create an organization first, then add groups there.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  'Each row is a group (team or circle) and shows which organization it belongs to.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.45,
                  ),
                );
              }
              final entry = entries[index - 1];
              return Card(
                child: ListTile(
                  leading: GroupBrandMark(
                    groupName: entry.group.name,
                    logoUrl: Organization.resolveLogoUrl(
                      organizationLogoUrl: entry.org.resolvedLogoUrl,
                      fallback: entry.group.logoUrl,
                    ),
                    orgId: entry.org.id,
                  ),
                  title: Text(entry.group.name),
                  subtitle: Text(
                    [
                      'Organization: ${entry.org.name}',
                      if (entry.group.ageBand != null &&
                          entry.group.ageBand!.isNotEmpty)
                        entry.group.ageBand!,
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupMembersScreen(
                          orgId: entry.org.id,
                          group: entry.group,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load groups:\n$e'),
          ),
        ),
      ),
    );
  }
}

class PlatformGroupEntry {
  const PlatformGroupEntry({
    required this.org,
    required this.group,
  });

  final Organization org;
  final MinistryGroup group;
}

final allPlatformGroupsProvider =
    FutureProvider<List<PlatformGroupEntry>>((ref) async {
  final isSuperAdmin = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
  if (!isSuperAdmin) return const [];

  final rows = await ref
      .read(organizationServiceProvider)
      .loadAllPlatformGroups();
  return rows
      .map((row) => PlatformGroupEntry(org: row.org, group: row.group))
      .toList();
});
