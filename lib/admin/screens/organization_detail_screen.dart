import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../config/admin_config.dart';
import '../models/admin_role.dart';
import '../models/group_membership_invite.dart';
import '../models/ministry_group.dart';
import '../models/organization.dart';
import '../models/organization_invite.dart';
import '../models/organization_membership.dart';
import '../providers/admin_providers.dart';
import '../services/group_invite_service.dart';
import '../services/organization_service.dart';
import '../widgets/admin_hierarchy_hint.dart';
import '../widgets/role_gate.dart';
import '../../widgets/group_brand_mark.dart';
import 'bulk_provision_users_screen.dart';
import 'create_group_gift_screen.dart';
import 'edit_organization_screen.dart';
import 'group_gifts_screen.dart';
import 'group_members_screen.dart';
import 'group_schedules_screen.dart';
import 'invite_members_screen.dart';
import 'org_pastoral_insights_screen.dart';
import 'org_calendar_admin_screen.dart';

class OrganizationDetailScreen extends ConsumerWidget {
  const OrganizationDetailScreen({
    super.key,
    required this.orgId,
  });

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgAsync = ref.watch(organizationProvider(orgId));
    final canViewInsights = ref.watch(canViewOrgInsightsProvider(orgId));
    final isAdmin = ref.watch(isOrganizationAdminProvider(orgId));
    final canManageGroups = ref.watch(canManageOrgGroupsProvider(orgId));

    return orgAsync.when(
      data: (org) {
        if (org == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Organization')),
            body: const Center(child: Text('Organization not found')),
          );
        }

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(org.name, overflow: TextOverflow.ellipsis),
              centerTitle: true,
              actions: [
                if (isAdmin)
                  IconButton(
                    tooltip: 'Edit organization',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      openEditOrganizationScreen(
                        context,
                        orgId: orgId,
                      );
                    },
                  ),
                IconButton(
                  tooltip: 'School / Organization Calendar',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrgCalendarAdminScreen(
                          orgId: orgId,
                          organizationName: org.name,
                        ),
                      ),
                    );
                  },
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                labelColor: AppColors.textOnMaroon,
                unselectedLabelColor: AppColors.textOnMaroon.withValues(alpha: 0.72),
                indicatorColor: AppColors.textOnMaroon,
                dividerColor: Colors.white.withValues(alpha: 0.25),
                tabs: const [
                  Tab(text: 'Groups'),
                  Tab(text: 'Members'),
                  Tab(text: 'Organization invites'),
                  Tab(text: 'Group invites'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _GroupsTab(
                  orgId: orgId,
                  orgName: org.name,
                  orgLogoUrl: org.resolvedLogoUrl,
                  canManageGroups: canManageGroups,
                  isAdmin: isAdmin,
                ),
                _MembersTab(
                  orgId: orgId,
                  orgName: org.name,
                  isAdmin: isAdmin,
                  canManageGroups: canManageGroups,
                ),
                _InvitesTab(orgId: orgId, isAdmin: isAdmin),
                _GroupInvitesTab(orgId: orgId, isAdmin: isAdmin),
              ],
            ),
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RoleGate(
                  allowed: canViewInsights,
                  child: FloatingActionButton.extended(
                    heroTag: 'insights',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OrgPastoralInsightsScreen(orgId: orgId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.insights_outlined),
                    label: const Text('Pastoral Insights'),
                  ),
                ),
                if (canViewInsights) const SizedBox(height: 12),
                RoleGate(
                  allowed: isAdmin,
                  child: FloatingActionButton.extended(
                    heroTag: 'bulk',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BulkProvisionUsersScreen(orgId: orgId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Bulk add users'),
                  ),
                ),
                if (isAdmin) const SizedBox(height: 12),
                RoleGate(
                  allowed: isAdmin,
                  child: FloatingActionButton.extended(
                    heroTag: 'invite',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InviteMembersScreen(orgId: orgId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Invite'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Organization')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Organization')),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab({
    required this.orgId,
    required this.orgName,
    this.orgLogoUrl,
    required this.canManageGroups,
    required this.isAdmin,
  });

  final String orgId;
  final String orgName;
  final String? orgLogoUrl;
  final bool canManageGroups;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(organizationGroupsProvider(orgId));
    final members =
        ref.watch(organizationMembersProvider(orgId)).valueOrNull ?? const [];
    final invites =
        ref.watch(organizationGroupInvitesProvider(orgId)).valueOrNull ?? const [];
    final orgInvites =
        ref.watch(organizationInvitesProvider(orgId)).valueOrNull ?? const [];
    final service = ref.read(organizationServiceProvider);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    OrganizationMembership? myMembership;
    if (currentUid != null) {
      for (final member in members) {
        if (member.uid == currentUid) {
          myMembership = member;
          break;
        }
      }
    }

    return groupsAsync.when(
      data: (groups) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            AdminOrganizationGroupsHeader(
              organizationName: orgName,
              orgId: orgId,
              logoUrl: orgLogoUrl,
            ),
            const SizedBox(height: 12),
            const AdminHierarchyHint(compact: true),
            const SizedBox(height: 12),
            if (isAdmin) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit organization'),
                  subtitle: const Text(
                    'Change the name, type, and logo used by groups and Gifts.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    openEditOrganizationScreen(context, orgId: orgId);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('School / Organization Calendar'),
                subtitle: const Text(
                  'Shared schedule template — not personal Gifts or private prayer.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrgCalendarAdminScreen(
                        orgId: orgId,
                        organizationName: orgName,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Groups organize members and scope anonymized Pastoral Insights within this organization.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.45),
            ),
            const SizedBox(height: 12),
            if (groups.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No groups in this organization yet. Add a team or circle '
                    '(e.g. youth group, confirmation class, campus ministry).',
                  ),
                ),
              )
            else
              for (final group in groups)
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                  leading: GroupBrandMark(
                    groupName: group.name,
                    logoUrl: Organization.resolveLogoUrl(
                      organizationLogoUrl: orgLogoUrl,
                      fallback: group.logoUrl,
                    ),
                    orgId: orgId,
                  ),
                  title: Text(group.name),
                  subtitle: Text(
                    () {
                      final accepted = members
                          .where((m) => m.groupIds.contains(group.id))
                          .length;
                      final pending = GroupMembersScreen.pendingCount(
                        members: members,
                        groupInvites: invites,
                        orgInvites: orgInvites,
                        groupId: group.id,
                      );
                      final iAmMember =
                          myMembership?.groupIds.contains(group.id) ?? false;
                      final details = [
                        if (accepted > 0) '$accepted accepted',
                        if (pending > 0) '$pending pending',
                        if (accepted == 0 && pending == 0) '0 members',
                        if (myMembership != null && !iAmMember)
                          'You are not a member yet',
                        if (group.ageBand != null && group.ageBand!.isNotEmpty)
                          group.ageBand!,
                        if (group.description != null &&
                            group.description!.isNotEmpty)
                          group.description!,
                      ].join(' · ');
                      return 'Group · $details';
                    }(),
                  ),
                  trailing: canManageGroups
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<String>(
                            tooltip: 'Group actions',
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) async {
                              switch (value) {
                                case 'join':
                                  try {
                                    await service.joinGroupAsCurrentMember(
                                      orgId: orgId,
                                      groupId: group.id,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Joined ${group.name}. You can now '
                                            'share to this group in User mode.',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text('$e')),
                                      );
                                    }
                                  }
                                case 'members':
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GroupMembersScreen(
                                        orgId: orgId,
                                        group: group,
                                      ),
                                    ),
                                  );
                                case 'createGift':
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CreateGroupGiftScreen(
                                        orgId: orgId,
                                        group: group,
                                        organizationName: orgName,
                                      ),
                                    ),
                                  );
                                case 'gifts':
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GroupGiftsScreen(
                                        orgId: orgId,
                                        group: group,
                                        organizationName: orgName,
                                      ),
                                    ),
                                  );
                                case 'schedules':
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GroupSchedulesScreen(
                                        orgId: orgId,
                                        group: group,
                                        organizationName: orgName,
                                      ),
                                    ),
                                  );
                                case 'edit':
                                  await _showGroupDialog(
                                    context,
                                    service: service,
                                    orgId: orgId,
                                    existing: group,
                                  );
                                case 'delete':
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete group?'),
                                      content: Text(
                                        'Remove "${group.name}"? Member assignments '
                                        'may need to be updated.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true || !context.mounted) {
                                    return;
                                  }
                                  try {
                                    await service.deleteGroup(
                                      orgId: orgId,
                                      groupId: group.id,
                                    );
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text('$e')),
                                      );
                                    }
                                  }
                              }
                            },
                            itemBuilder: (ctx) {
                              final canManageGifts = ref.read(
                                canManageGroupGiftsProvider((orgId, group.id)),
                              );
                              return [
                              if (myMembership != null &&
                                  !myMembership.groupIds.contains(group.id))
                                const PopupMenuItem(
                                  value: 'join',
                                  child: Text('Join as member'),
                                ),
                              const PopupMenuItem(
                                value: 'members',
                                child: Text('View members'),
                              ),
                              if (canManageGifts) ...[
                                const PopupMenuItem(
                                  value: 'createGift',
                                  child: Text('Create group Gift'),
                                ),
                                const PopupMenuItem(
                                  value: 'gifts',
                                  child: Text('Group Gifts'),
                                ),
                              ],
                              if (isAdmin)
                                const PopupMenuItem(
                                  value: 'schedules',
                                  child: Text('Group schedules'),
                                ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit group'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete group'),
                              ),
                            ];
                            },
                          ),
                              const Icon(Icons.chevron_right),
                            ],
                          )
                        : null,
                    onTap: canManageGroups
                        ? () => _showGroupDialog(
                              context,
                              service: service,
                              orgId: orgId,
                              existing: group,
                            )
                        : null,
                  ),
                  if (ref.watch(canManageGroupGiftsProvider((orgId, group.id))))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateGroupGiftScreen(
                                    orgId: orgId,
                                    group: group,
                                    organizationName: orgName,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.card_giftcard),
                            label: const Text('Create group Gift'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupGiftsScreen(
                                    orgId: orgId,
                                    group: group,
                                    organizationName: orgName,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.list_alt),
                            label: const Text('Group Gifts'),
                          ),
                        ],
                      ),
                    ),
                    ],
                  ),
                ),
            if (canManageGroups) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showGroupDialog(
                  context,
                  service: service,
                  orgId: orgId,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add group'),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Future<void> _showGroupDialog(
    BuildContext context, {
    required OrganizationService service,
    required String orgId,
    MinistryGroup? existing,
  }) async {
    final result = await showDialog<_GroupEditResult>(
      context: context,
      builder: (ctx) => _EditGroupDialog(
        existing: existing,
        orgId: orgId,
        orgLogoUrl: orgLogoUrl,
      ),
    );

    if (result == null || !context.mounted) return;

    try {
      if (existing == null) {
        await service.createGroup(
          orgId: orgId,
          name: result.name,
          ageBand: result.ageBand,
          description: result.description,
          logoUrl: result.logoUrl,
        );
      } else {
        await service.updateGroup(
          orgId: orgId,
          groupId: existing.id,
          name: result.name,
          ageBand: result.ageBand,
          description: result.description,
          logoUrl: result.logoUrl,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }
}

class _GroupEditResult {
  const _GroupEditResult({
    required this.name,
    required this.ageBand,
    required this.description,
    required this.logoUrl,
  });

  final String name;
  final String? ageBand;
  final String description;
  final String logoUrl;
}

class _EditGroupDialog extends StatefulWidget {
  const _EditGroupDialog({
    required this.existing,
    required this.orgId,
    this.orgLogoUrl,
  });

  final MinistryGroup? existing;
  final String orgId;
  final String? orgLogoUrl;

  @override
  State<_EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<_EditGroupDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _logoUrlController;
  String? _ageBand;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descController = TextEditingController(text: existing?.description ?? '');
    _logoUrlController = TextEditingController(text: existing?.logoUrl ?? '');
    _ageBand = existing?.ageBand;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupUrl = _logoUrlController.text.trim();
    final previewUrl = groupUrl.isNotEmpty ? groupUrl : widget.orgLogoUrl;
    final previewName = _nameController.text.trim().isEmpty
        ? (widget.existing?.name ?? 'Group')
        : _nameController.text.trim();

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add group' : 'Edit group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GroupBrandMark(
              groupName: previewName,
              logoUrl: previewUrl,
              orgId: widget.orgId,
              size: 72,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a group image by HTTPS URL, or leave blank to use the '
              'organization logo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _logoUrlController,
              decoration: const InputDecoration(
                labelText: 'Group image URL (optional)',
                hintText: 'https://…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _ageBand,
              decoration: const InputDecoration(
                labelText: 'Age band (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None'),
                ),
                ...AdminConfig.suggestedAgeBands.map(
                  (band) => DropdownMenuItem(value: band, child: Text(band)),
                ),
              ],
              onChanged: (value) => setState(() => _ageBand = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
              _GroupEditResult(
                name: _nameController.text,
                ageBand: _ageBand,
                description: _descController.text,
                logoUrl: _logoUrlController.text,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({
    required this.orgId,
    required this.orgName,
    required this.isAdmin,
    required this.canManageGroups,
  });

  final String orgId;
  final String orgName;
  final bool isAdmin;
  final bool canManageGroups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(organizationMembersProvider(orgId));
    final groups =
        ref.watch(organizationGroupsProvider(orgId)).valueOrNull ?? const [];
    final orgService = ref.read(organizationServiceProvider);
    final inviteService = ref.read(groupInviteServiceProvider);

    return membersAsync.when(
      data: (members) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final member = members[index];
            return _MemberTile(
              member: member,
              groups: groups,
              isAdmin: isAdmin,
              canManageGroups: canManageGroups,
              onRoleChanged: isAdmin
                  ? (role) => orgService.updateMemberRole(
                        orgId: orgId,
                        memberUid: member.uid,
                        role: role,
                      )
                  : null,
              onRemove: isAdmin
                  ? () => orgService.removeMember(
                        orgId: orgId,
                        memberUid: member.uid,
                      )
                  : null,
              onInviteToGroup: canManageGroups && groups.isNotEmpty
                  ? () => _showInviteToGroupDialog(
                        context,
                        orgId: orgId,
                        orgName: orgName,
                        member: member,
                        groups: groups,
                        inviteService: inviteService,
                      )
                  : null,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Future<void> _showInviteToGroupDialog(
    BuildContext context, {
    required String orgId,
    required String orgName,
    required OrganizationMembership member,
    required List<MinistryGroup> groups,
    required GroupInviteService inviteService,
  }) async {
    final eligible = groups
        .where((g) => !member.groupIds.contains(g.id))
        .toList();
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member is already in all groups.')),
      );
      return;
    }

    MinistryGroup? selected = eligible.first;
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite to group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send a consent invitation to '
              '${member.displayName ?? member.email ?? 'this member'}. '
              'They must accept before joining.',
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MinistryGroup>(
              value: selected,
              decoration: const InputDecoration(
                labelText: 'Group',
                border: OutlineInputBorder(),
              ),
              items: eligible
                  .map(
                    (g) => DropdownMenuItem(value: g, child: Text(g.name)),
                  )
                  .toList(),
              onChanged: (value) => selected = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send invitation'),
          ),
        ],
      ),
    );

    if (sent != true || selected == null || !context.mounted) return;

    try {
      await inviteService.inviteMemberToGroup(
        orgId: orgId,
        member: member,
        groupId: selected!.id,
        groupName: selected!.name,
        organizationName: orgName,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group invitation sent.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.groups,
    required this.isAdmin,
    required this.canManageGroups,
    this.onRoleChanged,
    this.onRemove,
    this.onInviteToGroup,
  });

  final OrganizationMembership member;
  final List<MinistryGroup> groups;
  final bool isAdmin;
  final bool canManageGroups;
  final ValueChanged<AdminRole>? onRoleChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onInviteToGroup;

  @override
  Widget build(BuildContext context) {
    final groupNames = member.groupIds
        .map((id) => groups.where((g) => g.id == id).map((g) => g.name))
        .expand((e) => e)
        .join(', ');

    return Card(
      child: ListTile(
        title: Text(member.displayName ?? member.email ?? 'Member'),
        subtitle: Text(
          [
            member.role.label,
            if (groupNames.isNotEmpty) groupNames,
          ].join(' · '),
        ),
        trailing: isAdmin
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'invite') {
                    onInviteToGroup?.call();
                  } else {
                    onRoleChanged?.call(AdminRole.values.byName(value));
                  }
                },
                itemBuilder: (ctx) => [
                  if (canManageGroups && onInviteToGroup != null)
                    const PopupMenuItem(
                      value: 'invite',
                      child: Text('Invite to group'),
                    ),
                  ...AdminRole.values.map(
                    (role) => PopupMenuItem(
                      value: role.name,
                      child: Text('Set role: ${role.label}'),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              )
            : null,
        onLongPress: isAdmin && onRemove != null
            ? () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove member?'),
                    content: const Text(
                      'This removes organizational access only. Personal '
                      'spiritual data remains private.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) onRemove?.call();
              }
            : null,
      ),
    );
  }
}

class _GroupInvitesTab extends ConsumerStatefulWidget {
  const _GroupInvitesTab({required this.orgId, required this.isAdmin});

  final String orgId;
  final bool isAdmin;

  @override
  ConsumerState<_GroupInvitesTab> createState() => _GroupInvitesTabState();
}

class _GroupInvitesTabState extends ConsumerState<_GroupInvitesTab> {
  @override
  void initState() {
    super.initState();
    if (widget.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(groupInviteServiceProvider)
            .repairAllPendingGroupInviteIndexes(widget.orgId)
            .catchError((_) {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Group invitation status is visible to organization administrators.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final invitesAsync =
        ref.watch(organizationGroupInvitesProvider(widget.orgId));

    return invitesAsync.when(
      data: (invites) {
        if (invites.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No group invitations yet. Use Members → Invite to group to '
                'send consent-based invitations.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: invites.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final invite = invites[index];
            return Card(
              child: ListTile(
                title: Text(invite.groupName),
                subtitle: Text(
                  invite.inviteeEmail.isNotEmpty ? invite.inviteeEmail : 'Invited member'
                  ' · ${_statusLabel(invite.status)}',
                ),
                trailing: _statusIcon(invite.status),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  String _statusLabel(GroupInviteStatus status) {
    switch (status) {
      case GroupInviteStatus.pending:
        return 'Pending';
      case GroupInviteStatus.accepted:
        return 'Accepted';
      case GroupInviteStatus.rejected:
        return 'Rejected';
    }
  }

  Widget? _statusIcon(GroupInviteStatus status) {
    switch (status) {
      case GroupInviteStatus.pending:
        return Icon(Icons.hourglass_top, color: Colors.orange.shade700);
      case GroupInviteStatus.accepted:
        return Icon(Icons.check_circle_outline, color: Colors.green.shade700);
      case GroupInviteStatus.rejected:
        return Icon(Icons.cancel_outlined, color: Colors.red.shade700);
    }
  }
}

class _InvitesTab extends ConsumerStatefulWidget {
  const _InvitesTab({required this.orgId, required this.isAdmin});

  final String orgId;
  final bool isAdmin;

  @override
  ConsumerState<_InvitesTab> createState() => _InvitesTabState();
}

class _InvitesTabState extends ConsumerState<_InvitesTab> {
  bool _repairing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshDelivery());
    }
  }

  Future<void> _refreshDelivery() async {
    if (!widget.isAdmin || _repairing) return;
    setState(() => _repairing = true);
    try {
      await ref
          .read(organizationServiceProvider)
          .repairAllPendingOrgInviteDelivery(widget.orgId);
    } catch (_) {
      // Shown only when admin explicitly taps refresh.
    } finally {
      if (mounted) setState(() => _repairing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitesAsync = ref.watch(organizationInvitesProvider(widget.orgId));
    final service = ref.read(organizationServiceProvider);

    return invitesAsync.when(
      data: (invites) {
        if (invites.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.isAdmin
                        ? 'No invitations yet. Tap Invite to add members by email.'
                        : 'No pending invitations.',
                    textAlign: TextAlign.center,
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _repairing ? null : _refreshDelivery,
                      icon: _repairing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Refresh delivery'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            if (widget.isAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _repairing ? null : _refreshDelivery,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      _repairing ? 'Refreshing…' : 'Refresh delivery',
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: invites.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final invite = invites[index];
            return Card(
              child: ListTile(
                title: Text(invite.email),
                subtitle: Text('${invite.role.label} · ${invite.status.name}'),
                trailing: widget.isAdmin && invite.status == InviteStatus.pending
                    ? IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        onPressed: () => service.revokeInvite(
                          orgId: widget.orgId,
                          invite: invite,
                        ),
                      )
                    : null,
              ),
            );
          },
        ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}
