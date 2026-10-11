import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../email/institutional_email_copy.dart';
import '../models/ministry_group.dart';
import '../models/organization_membership.dart';
import '../models/user_directory.dart';
import '../providers/admin_providers.dart';
import '../services/platform_admin_service.dart';
import '../widgets/email_preview_dialog.dart';
import 'bulk_provision_users_screen.dart';
import 'invite_members_screen.dart';

enum _DirectoryFilter { all, unaffiliated, pending }

/// Overall Admin directory of registered WWJD-DI users (not anonymous guests).
class PlatformUsersScreen extends ConsumerStatefulWidget {
  const PlatformUsersScreen({super.key});

  @override
  ConsumerState<PlatformUsersScreen> createState() =>
      _PlatformUsersScreenState();
}

class _PlatformUsersScreenState extends ConsumerState<PlatformUsersScreen> {
  AsyncValue<UserDirectory>? _directory;
  _DirectoryFilter _filter = _DirectoryFilter.all;
  String? _orgId;
  String? _groupId;
  String _query = '';

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
        _directory = AsyncValue.error(
          Exception('Overall Admin access required.'),
          StackTrace.current,
        );
      });
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _directory = const AsyncValue.loading());
    try {
      final directory =
          await ref.read(userDirectoryServiceProvider).fetchDirectory();
      if (!mounted) return;
      setState(() => _directory = AsyncValue.data(directory));
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _directory = AsyncValue.error(e, st));
    }
  }

  void _setFilter(_DirectoryFilter filter) {
    setState(() {
      _filter = filter;
      if (filter != _DirectoryFilter.all) {
        _orgId = null;
        _groupId = null;
      }
    });
  }

  List<DirectoryUser> _filteredUsers(UserDirectory directory) {
    var rows = directory.users;
    if (_filter == _DirectoryFilter.unaffiliated) {
      rows = directory.unaffiliatedUsers;
    } else if (_orgId != null && _orgId!.isNotEmpty) {
      rows = rows
          .where((user) => user.organizations.any((org) => org.id == _orgId))
          .toList();
    } else if (_groupId != null && _groupId!.isNotEmpty) {
      rows = rows
          .where((user) => user.groups.any((group) => group.id == _groupId))
          .toList();
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows
        .where(
          (user) =>
              user.email.toLowerCase().contains(query) ||
              user.displayName.toLowerCase().contains(query),
        )
        .toList();
  }

  List<DirectoryPendingInvite> _filteredPending(UserDirectory directory) {
    var rows = directory.pendingInvites;
    if (_orgId != null && _orgId!.isNotEmpty) {
      rows = rows.where((row) => row.organizationId == _orgId).toList();
    }
    if (_groupId != null && _groupId!.isNotEmpty) {
      rows = rows.where((row) => row.groupId == _groupId).toList();
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows
        .where(
          (row) =>
              row.email.toLowerCase().contains(query) ||
              (row.displayName ?? '').toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _inviteToWwjdDi({String? email}) async {
    final controller = TextEditingController(text: email ?? '');
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite to WWJD-DI'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: email == null,
          decoration: const InputDecoration(
            labelText: 'Email address',
            border: OutlineInputBorder(),
            helperText: 'No organization or group is assigned.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Review invitation'),
          ),
        ],
      ),
    );
    if (entered == null || !mounted) return;
    if (!entered.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    final copy = InstitutionalEmailCopy.platformInvite(inviteeEmail: entered);
    final draft = await showEmailPreviewDialog(
      context: context,
      title: 'Preview invitation',
      toLabel: entered,
      subject: copy.subject,
      body: copy.text,
      helperText:
          'No WWJD-DI account is created until they register. '
          'No school, parish, or ministry is assigned.',
    );
    if (draft == null || !mounted) return;

    try {
      final overrides = draft.overrideFields;
      final result = await ref.read(userProvisioningServiceProvider).provisionUsers(
            target: 'platform',
            users: [ProvisionUserEntry(email: entered)],
            mode: 'invite',
            attachOrgInvite: false,
            emailSubject: overrides['emailSubject'],
            emailText: overrides['emailText'],
          );
      if (!mounted) return;
      final row = result.rows.isEmpty ? null : result.rows.first;
      final message = row == null
          ? 'Invitation submitted.'
          : row.skipped
              ? row.skipLabel
              : row.emailSent
                  ? 'Invitation sent'
                  : row.emailFailed
                      ? 'Invite saved; email failed${row.emailError == null ? '' : ': ${row.emailError}'}'
                      : 'Invitation submitted.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _inviteToOrganization(String email) async {
    final directory = _directory?.valueOrNull;
    final orgs = directory?.organizations ?? const [];
    if (orgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create an organization first.')),
      );
      return;
    }
    final selected = await showDialog<DirectoryMembership>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Invite to organization'),
        children: [
          for (final org in orgs)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, org),
              child: Text(org.label),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InviteMembersScreen(
          orgId: selected.id,
          initialEmail: email,
        ),
      ),
    );
    await _load();
  }

  Future<void> _inviteToGroup({
    required String email,
    String? uid,
    String? displayName,
  }) async {
    final directory = _directory?.valueOrNull;
    final groups = directory?.groups ?? const [];
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a group inside an organization first.'),
        ),
      );
      return;
    }
    final selected = await showDialog<DirectoryMembership>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(uid != null && uid.isNotEmpty ? 'Add to group' : 'Invite to group'),
        children: [
          for (final group in groups)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, group),
              child: Text(
                [
                  group.label,
                  if ((group.organizationName ?? '').trim().isNotEmpty)
                    group.organizationName!.trim(),
                ].join(' · '),
              ),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final orgId = selected.organizationId?.trim() ?? '';
    if (orgId.isEmpty) return;

    final orgName = (selected.organizationName ?? '').trim();
    final group = MinistryGroup(
      id: selected.id,
      organizationId: orgId,
      name: selected.label,
      createdAt: DateTime.now(),
    );

    OrganizationMembership? member;
    if (uid != null && uid.isNotEmpty) {
      final members =
          await ref.read(organizationServiceProvider).watchMembers(orgId).first;
      if (!mounted) return;
      try {
        member = members.firstWhere((m) => m.uid == uid);
      } catch (_) {
        member = null;
      }
    }

    if (uid != null && uid.isNotEmpty) {
      if (!mounted) return;
      final alreadyListed =
          member != null && member.groupIds.contains(group.id);
      final confirmed = alreadyListed
          ? true
          : await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add to group?'),
          content: Text(
            'Add $email to ${group.name}'
            '${orgName.isEmpty ? '' : ' in $orgName'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      try {
        final already = await ref
            .read(organizationServiceProvider)
            .addRegisteredUserToGroup(
              orgId: orgId,
              memberUid: uid,
              groupId: group.id,
              email: email,
              displayName: displayName,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              already
                  ? 'Already in ${group.name}.'
                  : 'Added to ${group.name}.',
            ),
          ),
        );
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
      return;
    }

    if (member != null) {
      if (!mounted) return;
      if (member.groupIds.contains(group.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already in this group.')),
        );
        return;
      }
      final copy = InstitutionalEmailCopy.groupInvite(
        groupName: group.name,
        organizationName: orgName.isEmpty ? null : orgName,
      );
      final draft = await showEmailPreviewDialog(
        context: context,
        title: 'Preview invitation',
        toLabel: email,
        subject: copy.subject,
        body: copy.text,
      );
      if (draft == null || !mounted) return;
      try {
        final overrides = draft.overrideFields;
        await ref.read(groupInviteServiceProvider).inviteMemberToGroup(
              orgId: orgId,
              member: member,
              groupId: group.id,
              groupName: group.name,
              organizationName: orgName.isEmpty ? null : orgName,
              emailSubject: overrides['emailSubject'],
              emailText: overrides['emailText'],
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent')),
        );
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InviteMembersScreen(
          orgId: orgId,
          initialEmail: email,
          initialGroupIds: [group.id],
        ),
      ),
    );
    await _load();
  }

  Future<void> _resend(DirectoryPendingInvite invite) async {
    try {
      await ref.read(userDirectoryServiceProvider).resendInvite(
            kind: invite.kind,
            inviteId: invite.id,
            orgId: invite.organizationId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation email resent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
    if (!isSuperAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Users')),
        body: const Center(child: Text('Overall Admin access required.')),
      );
    }

    final directoryAsync = _directory ?? const AsyncValue.loading();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: directoryAsync.isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: directoryAsync.when(
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
        data: (directory) => _buildDirectory(context, directory),
      ),
    );
  }

  Widget _buildDirectory(BuildContext context, UserDirectory directory) {
    final showPending = _filter == _DirectoryFilter.pending;
    final users = showPending ? const <DirectoryUser>[] : _filteredUsers(directory);
    final pending = _filteredPending(directory);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Registered WWJD-DI accounts. Anonymous guest sessions are counted '
          'separately and are not listed here. Seeking God\'s Wisdom, '
          'Reflections, and personal Gifts are never shown.',
          style: TextStyle(color: Colors.grey.shade800, height: 1.45),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              label: Text('${directory.users.length} registered'),
            ),
            Chip(
              label: Text(
                '${directory.guestCount} guest session${directory.guestCount == 1 ? '' : 's'}',
              ),
            ),
            Chip(
              label: Text('${directory.pendingInvites.length} pending invites'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _inviteToWwjdDi(),
              icon: const Icon(Icons.mail_outline),
              label: const Text('Invite to WWJD-DI'),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BulkProvisionUsersScreen(),
                  ),
                ).then((_) => _load());
              },
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Bulk add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: _filter == _DirectoryFilter.all &&
                  _orgId == null &&
                  _groupId == null,
              onSelected: (_) => _setFilter(_DirectoryFilter.all),
            ),
            FilterChip(
              label: const Text('Unaffiliated'),
              tooltip: 'No organization and no group — admin filter only',
              selected: _filter == _DirectoryFilter.unaffiliated,
              onSelected: (_) => _setFilter(_DirectoryFilter.unaffiliated),
            ),
            FilterChip(
              label: const Text('Pending invites'),
              selected: _filter == _DirectoryFilter.pending,
              onSelected: (_) => _setFilter(_DirectoryFilter.pending),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          value: _orgId,
          decoration: const InputDecoration(
            labelText: 'Organization',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All organizations'),
            ),
            for (final org in directory.organizations)
              DropdownMenuItem<String?>(
                value: org.id,
                child: Text(org.label),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _orgId = value;
              _groupId = null;
              if (value != null) _filter = _DirectoryFilter.all;
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          value: _groupId,
          decoration: const InputDecoration(
            labelText: 'Group',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All groups'),
            ),
            for (final group in directory.groups.where(
              (g) => _orgId == null || g.organizationId == _orgId,
            ))
              DropdownMenuItem<String?>(
                value: group.id,
                child: Text(
                  [
                    group.label,
                    if ((group.organizationName ?? '').trim().isNotEmpty)
                      group.organizationName!.trim(),
                  ].join(' · '),
                ),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _groupId = value;
              if (value != null) _filter = _DirectoryFilter.all;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search name or email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        if (showPending) ...[
          if (pending.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No pending invitations match this filter.'),
            )
          else
            for (final invite in pending)
              _PendingInviteCard(
                invite: invite,
                dateFormat: dateFormat,
                onInviteWwjdDi: invite.kind == 'platform' || invite.hasAccount
                    ? null
                    : () => _inviteToWwjdDi(email: invite.email),
                onInviteOrg: () => _inviteToOrganization(invite.email),
                onInviteGroup: () => _inviteToGroup(email: invite.email),
                onResend: () => _resend(invite),
              ),
        ] else ...[
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No registered users match this filter.'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Last active')),
                  DataColumn(label: Text('Organizations')),
                  DataColumn(label: Text('Groups')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final user in users)
                    DataRow(
                      cells: [
                        DataCell(Text(user.nameLabel)),
                        DataCell(Text(user.email.isEmpty ? '—' : user.email)),
                        const DataCell(Text('Registered')),
                        DataCell(
                          Text(
                            user.lastActive == null
                                ? '—'
                                : dateFormat.format(user.lastActive!.toLocal()),
                          ),
                        ),
                        DataCell(Text(user.organizationLabels)),
                        DataCell(Text(user.groupLabels)),
                        DataCell(
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'org':
                                  _inviteToOrganization(user.email);
                                case 'group':
                                  _inviteToGroup(
                                    email: user.email,
                                    uid: user.uid,
                                    displayName: user.displayName,
                                  );
                                case 'resend':
                                  final match = directory.pendingInvites
                                      .where((row) => row.email == user.email)
                                      .toList();
                                  if (match.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No pending invitation for this person.',
                                        ),
                                      ),
                                    );
                                  } else {
                                    _resend(match.first);
                                  }
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(
                                value: 'org',
                                child: Text('Invite to organization'),
                              ),
                              PopupMenuItem(
                                value: 'group',
                                child: Text('Add to group'),
                              ),
                              PopupMenuItem(
                                value: 'resend',
                                child: Text('Resend email'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _PendingInviteCard extends StatelessWidget {
  const _PendingInviteCard({
    required this.invite,
    required this.dateFormat,
    required this.onInviteOrg,
    required this.onInviteGroup,
    required this.onResend,
    this.onInviteWwjdDi,
  });

  final DirectoryPendingInvite invite;
  final DateFormat dateFormat;
  final VoidCallback? onInviteWwjdDi;
  final VoidCallback onInviteOrg;
  final VoidCallback onInviteGroup;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(invite.email),
        subtitle: Text(
          [
            invite.nameLabel == '—' ? null : invite.nameLabel,
            'Pending invite · ${invite.kindLabel}',
            if (invite.organizationLabels != '—') invite.organizationLabels,
            if (invite.groupLabels != '—') invite.groupLabels,
            if (invite.createdAt != null)
              dateFormat.format(invite.createdAt!.toLocal()),
          ].whereType<String>().join(' · '),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'wwjd':
                onInviteWwjdDi?.call();
              case 'org':
                onInviteOrg();
              case 'group':
                onInviteGroup();
              case 'resend':
                onResend();
            }
          },
          itemBuilder: (ctx) => [
            if (onInviteWwjdDi != null)
              const PopupMenuItem(
                value: 'wwjd',
                child: Text('Invite to WWJD-DI only'),
              ),
            const PopupMenuItem(
              value: 'org',
              child: Text('Invite to organization'),
            ),
            const PopupMenuItem(
              value: 'group',
              child: Text('Invite to group'),
            ),
            const PopupMenuItem(
              value: 'resend',
              child: Text('Resend email'),
            ),
          ],
        ),
      ),
    );
  }
}
