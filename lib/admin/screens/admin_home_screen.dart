import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/admin_config.dart';
import '../models/organization.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_hierarchy_hint.dart';
import '../../widgets/group_brand_mark.dart';
import 'create_organization_screen.dart';
import 'edit_organization_screen.dart';
import 'organization_detail_screen.dart';
import 'pending_invites_screen.dart';
import 'platform_groups_screen.dart';
import 'usage_report_screen.dart';

/// Entry point for parish/school/ministry administrators.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({
    super.key,
    this.embedded = false,
  });

  /// When true, rendered inside [AdminShellScreen] without its own app bar.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(userOrganizationsProvider);
    final pendingAsync = ref.watch(pendingOrgInvitesProvider);
    final isSuperAdmin = ref.watch(isSuperAdminProvider).valueOrNull ?? false;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
      children: [
        _PrivacyBanner(),
        const SizedBox(height: 12),
        const AdminHierarchyHint(),
        if (isSuperAdmin) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.indigo.shade50,
            child: ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined,
                  color: Colors.indigo.shade800),
              title: const Text('Overall Administrator'),
              subtitle: const Text(
                'Platform scope: create organizations, appoint leaders, '
                'and oversee groups. Private spiritual content remains inaccessible.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.groups_outlined, color: Colors.indigo.shade800),
              title: const Text('All groups'),
              subtitle: const Text(
                'Every ministry group across all organizations — for oversight only.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlatformGroupsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.analytics_outlined, color: Colors.indigo.shade800),
              title: const Text('Usage Report'),
              subtitle: const Text(
                'Aggregate adoption and engagement — no private spiritual content.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UsageReportScreen(),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 20),
        pendingAsync.when(
          data: (invites) {
            if (invites.isEmpty) return const SizedBox.shrink();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(
                  '${invites.length} pending invitation${invites.length == 1 ? '' : 's'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PendingInvitesScreen(),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        const AdminOrganizationsSectionHeader(),
        const SizedBox(height: 12),
        orgsAsync.when(
          data: (orgs) {
            if (orgs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.apartment_outlined,
                        size: 48,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No organizations yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a parish, school, or ministry organization to '
                        'manage groups and view anonymized Pastoral Insights.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final org in orgs) _OrganizationHomeCard(org: org),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Could not load organizations: $e'),
        ),
      ],
    );

    return Scaffold(
      primary: !embedded,
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Administration'),
              centerTitle: true,
            ),
      body: body,
      floatingActionButton: isSuperAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateOrganizationScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('New organization'),
            )
          : null,
    );
  }
}

class _OrganizationHomeCard extends ConsumerWidget {
  const _OrganizationHomeCard({required this.org});

  final Organization org;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(isOrganizationAdminProvider(org.id));

    return Card(
      child: ListTile(
        leading: GroupBrandMark(
          groupName: org.name,
          logoUrl: org.resolvedLogoUrl,
          orgId: org.id,
        ),
        title: Text(org.name),
        subtitle: Text('Organization · ${org.type.label}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
              IconButton(
                tooltip: 'Edit organization',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  openEditOrganizationScreen(context, orgId: org.id);
                },
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrganizationDetailScreen(orgId: org.id),
            ),
          );
        },
      ),
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
              AdminConfig.privacyNotice,
              style: const TextStyle(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
