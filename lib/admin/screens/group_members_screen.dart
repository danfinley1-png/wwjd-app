import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_role.dart';
import '../models/group_membership_invite.dart';
import '../models/ministry_group.dart';
import '../models/organization_invite.dart';
import '../models/organization_membership.dart';
import '../models/organization.dart';
import '../providers/admin_providers.dart';
import '../utils/group_member_list.dart';
import '../../widgets/group_brand_mark.dart';
import 'create_group_gift_screen.dart';
import 'group_gifts_screen.dart';

/// Lists members and invitations for a specific ministry group.
class GroupMembersScreen extends ConsumerWidget {
  const GroupMembersScreen({
    super.key,
    required this.orgId,
    required this.group,
  });

  final String orgId;
  final MinistryGroup group;

  static int pendingCount({
    required List<OrganizationMembership> members,
    required List<GroupMembershipInvite> groupInvites,
    required List<OrganizationInvite> orgInvites,
    required String groupId,
  }) {
    return pendingRosterCountForGroup(
      members: members,
      groupInvites: groupInvites,
      orgInvites: orgInvites,
      groupId: groupId,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
    final canView =
        isSuperAdmin || ref.watch(canManageOrgGroupsProvider(orgId));
    final canManageGifts =
        ref.watch(canManageGroupGiftsProvider((orgId, group.id)));
    final org = ref.watch(organizationProvider(orgId)).valueOrNull;
    final orgName = org?.name ?? '';
    final orgLogo = Organization.resolveLogoUrl(
      organizationLogoUrl: org?.resolvedLogoUrl,
      fallback: group.logoUrl,
    );
    final membersAsync = ref.watch(organizationMembersProvider(orgId));
    final invitesAsync = ref.watch(organizationGroupInvitesProvider(orgId));
    final orgInvitesAsync = ref.watch(organizationInvitesProvider(orgId));

    if (!canView) {
      return Scaffold(
        appBar: AppBar(title: Text(group.name)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only organization administrators and group leaders may view '
              'group membership.',
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
                  Text(group.name),
                  Text(
                    [
                      if (group.ageBand != null && group.ageBand!.isNotEmpty)
                        group.ageBand!,
                      'Members & invitations',
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (canManageGifts)
            IconButton(
              tooltip: 'Group Gifts',
              icon: const Icon(Icons.card_giftcard_outlined),
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
            ),
        ],
      ),
      floatingActionButton: canManageGifts
          ? FloatingActionButton.extended(
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
            )
          : null,
      body: Column(
        children: [
          if (canManageGifts)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: GroupBrandMark(
                        groupName: group.name,
                        logoUrl: orgLogo,
                        orgId: orgId,
                      ),
                      title: const Text('Create group Gift'),
                      subtitle: Text(
                        'Shared My Gifts branded with ${group.name}. '
                        'Active Gifts go to accepted members automatically.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
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
                    ),
                    ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: const Text('Group Gifts'),
                      subtitle: const Text(
                        'View Active and Inactive shared Gifts',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
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
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: membersAsync.when(
        data: (members) {
          return invitesAsync.when(
            data: (invites) {
              return orgInvitesAsync.when(
                data: (orgInvites) => _MemberListBody(
                  members: members,
                  invites: invites,
                  orgInvites: orgInvites,
                  groupId: group.id,
                ),
                loading: () => _MemberListBody(
                  members: members,
                  invites: invites,
                  orgInvites: const [],
                  groupId: group.id,
                  orgInvitesLoading: true,
                ),
                error: (e, _) => _MemberListBody(
                  members: members,
                  invites: invites,
                  orgInvites: const [],
                  groupId: group.id,
                  orgInvitesError: '$e',
                ),
              );
            },
            loading: () => _MemberListBody(
              members: members,
              invites: const [],
              orgInvites: const [],
              groupId: group.id,
              invitesLoading: true,
            ),
            error: (e, _) => _MemberListBody(
              members: members,
              invites: const [],
              orgInvites: const [],
              groupId: group.id,
              invitesError: '$e',
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load group members:\n$e\n\n'
              'If you are a Super Admin, deploy the latest Firestore rules and '
              'confirm your administrator account is registered, or sign in with the '
              'foundation admin email.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberListBody extends StatelessWidget {
  const _MemberListBody({
    required this.members,
    required this.invites,
    required this.orgInvites,
    required this.groupId,
    this.invitesLoading = false,
    this.invitesError,
    this.orgInvitesLoading = false,
    this.orgInvitesError,
  });

  final List<OrganizationMembership> members;
  final List<GroupMembershipInvite> invites;
  final List<OrganizationInvite> orgInvites;
  final String groupId;
  final bool invitesLoading;
  final String? invitesError;
  final bool orgInvitesLoading;
  final String? orgInvitesError;

  @override
  Widget build(BuildContext context) {
    final rows = buildGroupMemberList(
      members: members,
      invites: invites,
      groupId: groupId,
      orgInvites: orgInvites,
    );

    final stillLoading = invitesLoading || orgInvitesLoading;
    final loadErrors = [
      if (invitesError != null) invitesError,
      if (orgInvitesError != null) orgInvitesError,
    ];

    if (rows.isEmpty && !stillLoading && loadErrors.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No members or invitations for this group yet.\n\n'
            '• Members → Invite to group — for people already in the organization.\n'
            '• Invite (email) — assign this group under "Assign to groups" so '
            'pending org invitations appear here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (invitesLoading || orgInvitesLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        if (invitesError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Group invitation status could not be loaded:\n$invitesError',
                  style: TextStyle(color: Colors.orange.shade900, height: 1.4),
                ),
              ),
            ),
          ),
        if (orgInvitesError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Organization invitation status could not be loaded:\n$orgInvitesError',
                  style: TextStyle(color: Colors.orange.shade900, height: 1.4),
                ),
              ),
            ),
          ),
        ...rows.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GroupMemberTile(entry: entry),
          ),
        ),
      ],
    );
  }
}

class _GroupMemberTile extends StatelessWidget {
  const _GroupMemberTile({required this.entry});

  final GroupMemberListEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(entry.status).withValues(alpha: 0.15),
          child: Text(
            _initials(entry.displayName),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _statusColor(entry.status),
            ),
          ),
        ),
        title: Text(entry.displayName),
        subtitle: Text('${entry.role.label} · ${_statusLabel(entry.status)}'),
        trailing: _StatusChip(status: entry.status),
      ),
    );
  }

  String _initials(String label) {
    final parts = label.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return label.isNotEmpty ? label[0].toUpperCase() : '?';
  }

  String _statusLabel(GroupMemberListStatus status) {
    switch (status) {
      case GroupMemberListStatus.accepted:
        return 'Accepted';
      case GroupMemberListStatus.pending:
        return 'Pending group invite';
      case GroupMemberListStatus.pendingOrgInvite:
        return 'Pending org join';
      case GroupMemberListStatus.rejected:
        return 'Rejected';
    }
  }

  Color _statusColor(GroupMemberListStatus status) {
    switch (status) {
      case GroupMemberListStatus.accepted:
        return Colors.green.shade700;
      case GroupMemberListStatus.pending:
        return Colors.orange.shade800;
      case GroupMemberListStatus.pendingOrgInvite:
        return Colors.blue.shade700;
      case GroupMemberListStatus.rejected:
        return Colors.red.shade700;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final GroupMemberListStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      GroupMemberListStatus.accepted => ('Accepted', Colors.green.shade700),
      GroupMemberListStatus.pending => ('Pending', Colors.orange.shade800),
      GroupMemberListStatus.pendingOrgInvite =>
        ('Org invite', Colors.blue.shade700),
      GroupMemberListStatus.rejected => ('Rejected', Colors.red.shade700),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
