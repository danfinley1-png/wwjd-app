import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../email/institutional_email_copy.dart';
import '../models/admin_role.dart';
import '../models/ministry_group.dart';
import '../providers/admin_providers.dart';
import '../services/platform_admin_service.dart';
import '../widgets/email_preview_dialog.dart';

enum BulkRosterMode { invite, register }

enum BulkRosterTarget { organization, platform }

/// Bulk email upload: invitations (no Auth) or account creation (temp password).
class BulkProvisionUsersScreen extends ConsumerStatefulWidget {
  const BulkProvisionUsersScreen({super.key, this.orgId});

  /// When null, Overall Admin invites or registers for WWJD-DI only.
  final String? orgId;

  @override
  ConsumerState<BulkProvisionUsersScreen> createState() =>
      _BulkProvisionUsersScreenState();
}

class _BulkProvisionUsersScreenState extends ConsumerState<BulkProvisionUsersScreen> {
  final _inputController = TextEditingController();
  BulkRosterMode _mode = BulkRosterMode.invite;
  BulkRosterTarget _target = BulkRosterTarget.organization;
  final Set<String> _selectedGroupIds = {};
  bool _attachOrgInvite = true;
  bool _busy = false;
  BulkRosterResult? _result;
  String? _error;

  bool get _isPlatformTarget =>
      widget.orgId == null ||
      widget.orgId!.isEmpty ||
      _target == BulkRosterTarget.platform;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  List<ProvisionUserEntry> _parseInput() {
    final lines = _inputController.text.split(RegExp(r'\r?\n'));
    final entries = <ProvisionUserEntry>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      final email = parts.first.trim();
      final name = parts.length > 1 ? parts.sublist(1).join(',').trim() : null;
      if (email.contains('@')) {
        entries.add(ProvisionUserEntry(email: email, displayName: name));
      }
    }
    return entries;
  }

  Future<void> _reviewAndSubmit({required bool canRegister}) async {
    final entries = _parseInput();
    if (entries.isEmpty) {
      setState(() => _error = 'Enter at least one email (one per line).');
      return;
    }
    if (_mode == BulkRosterMode.register && !canRegister) {
      setState(() {
        _error =
            'Only organization administrators can create accounts. '
            'Use Send invitations instead.';
      });
      return;
    }

    final orgId = widget.orgId;
    final org = (!_isPlatformTarget && orgId != null)
        ? ref.read(organizationProvider(orgId)).valueOrNull
        : null;
    final groups = (!_isPlatformTarget && orgId != null)
        ? ref.read(organizationGroupsProvider(orgId)).valueOrNull ??
            const <MinistryGroup>[]
        : const <MinistryGroup>[];
    final groupNames = _isPlatformTarget
        ? const <String>[]
        : groups
            .where((g) => _selectedGroupIds.contains(g.id))
            .map((g) => g.name)
            .toList();
    final sample = entries.first;
    final isInvite = _mode == BulkRosterMode.invite;
    final copy = isInvite
        ? (_isPlatformTarget
            ? InstitutionalEmailCopy.platformInvite(inviteeEmail: sample.email)
            : InstitutionalEmailCopy.organizationInvite(
                inviteeEmail: sample.email,
                organizationName: org?.name ?? 'your organization',
                role: AdminRole.member,
                groupNames: groupNames,
              ))
        : InstitutionalEmailCopy.welcome(
            email: sample.email,
            displayName: sample.displayName,
            organizationName: _isPlatformTarget ? null : org?.name,
          );
    final toLabel = entries.length == 1
        ? sample.email
        : '${sample.email} (+${entries.length - 1} more)';

    final draft = await showEmailPreviewDialog(
      context: context,
      title: isInvite ? 'Preview invitation' : 'Preview welcome email',
      toLabel: toLabel,
      subject: copy.subject,
      body: copy.text,
      helperText: isInvite
          ? (_isPlatformTarget
              ? (entries.length > 1
                  ? 'This preview uses the first recipient. Each person is invited '
                      'to WWJD-DI only — no organization or group is assigned.'
                  : 'Invited to WWJD-DI only. No organization or group is assigned.')
              : (entries.length > 1
                  ? 'This preview uses the first recipient. Each person receives '
                      'their own invitation. No WWJD-DI account is created until '
                      'they register and Accept.'
                  : 'No WWJD-DI account is created until they register and Accept.'))
          : (entries.length > 1
              ? 'This preview uses the first recipient. Each new account gets '
                  'its own temporary password when Send creates it.'
              : 'A unique temporary password is inserted when Send creates the account.'),
    );
    if (draft == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      final overrides = draft.overrideFields;
      final result = await ref.read(userProvisioningServiceProvider).provisionUsers(
            orgId: _isPlatformTarget ? null : widget.orgId,
            target: _isPlatformTarget ? 'platform' : 'organization',
            users: entries,
            mode: isInvite ? 'invite' : 'register',
            groupIds: _isPlatformTarget ? const [] : _selectedGroupIds.toList(),
            attachOrgInvite: !_isPlatformTarget && !isInvite && _attachOrgInvite,
            emailSubject: overrides['emailSubject'],
            emailText: overrides['emailText'],
          );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgId = widget.orgId;
    final groupsAsync = (!_isPlatformTarget && orgId != null)
        ? ref.watch(organizationGroupsProvider(orgId))
        : null;
    final membership = (!_isPlatformTarget && orgId != null)
        ? ref.watch(organizationMembershipProvider(orgId)).valueOrNull
        : null;
    final org = (!_isPlatformTarget && orgId != null)
        ? ref.watch(organizationProvider(orgId)).valueOrNull
        : null;
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isSuper = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
    final canRegister = isSuper ||
        membership?.role == AdminRole.orgAdmin ||
        (org != null && uid != null && org.createdByUid == uid);
    final showTargetChoice = isSuper && orgId != null && orgId.isNotEmpty;

    if (_mode == BulkRosterMode.register && !canRegister) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mode == BulkRosterMode.register && !canRegister) {
          setState(() => _mode = BulkRosterMode.invite);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk add')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Choose one mode. Invitations do not create login accounts. '
            'Creating accounts does.',
            style: TextStyle(color: Colors.grey.shade800, height: 1.45),
          ),
          const SizedBox(height: 12),
          RadioListTile<BulkRosterMode>(
            value: BulkRosterMode.invite,
            groupValue: _mode,
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) setState(() => _mode = value);
                  },
            title: const Text('Send invitations'),
            subtitle: const Text(
              'Mode A — pending invitation only. Recipients register or sign in. '
              'Organization or group membership is added only after they Accept '
              'when an institution is included.',
            ),
          ),
          RadioListTile<BulkRosterMode>(
            value: BulkRosterMode.register,
            groupValue: _mode,
            onChanged: _busy || !canRegister
                ? null
                : (value) {
                    if (value != null) setState(() => _mode = value);
                  },
            title: const Text('Create accounts (temporary password)'),
            subtitle: Text(
              canRegister
                  ? 'Mode B — creates a WWJD-DI login now. First sign-in requires '
                      'Create a new password before the rest of the app.'
                  : 'Organization administrators only.',
            ),
          ),
          if (showTargetChoice) ...[
            const SizedBox(height: 8),
            RadioListTile<BulkRosterTarget>(
              value: BulkRosterTarget.organization,
              groupValue: _target,
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => _target = value);
                    },
              title: Text('This organization${org == null ? '' : ': ${org.name}'}'),
              subtitle: const Text('Invite or register with this institution.'),
            ),
            RadioListTile<BulkRosterTarget>(
              value: BulkRosterTarget.platform,
              groupValue: _target,
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _target = value;
                          _selectedGroupIds.clear();
                        });
                      }
                    },
              title: const Text('WWJD-DI only'),
              subtitle: const Text(
                'No organization or group. Personal WWJD-DI features only until '
                'they accept a later invitation.',
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _isPlatformTarget
                ? 'Target: WWJD-DI only'
                : 'Target: ${org?.name ?? 'this organization'}'
                    '${_selectedGroupIds.isEmpty ? '' : ' · ${_selectedGroupIds.length} group(s)'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (_isPlatformTarget)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No school, parish, or ministry is assigned. Recipients use '
                'personal WWJD-DI features until they accept an invitation.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.45),
              ),
            )
          else if (groupsAsync != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return Text(
                      'No groups yet. Invitations will be for the organization only.',
                      style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assign to groups (optional)'),
                      for (final group in groups)
                        CheckboxListTile(
                          value: _selectedGroupIds.contains(group.id),
                          onChanged: _busy
                              ? null
                              : (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedGroupIds.add(group.id);
                                    } else {
                                      _selectedGroupIds.remove(group.id);
                                    }
                                  });
                                },
                          title: Text(group.name),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
            ),
          if (!_isPlatformTarget && _mode == BulkRosterMode.register) ...[
            CheckboxListTile(
              value: _attachOrgInvite,
              onChanged: _busy
                  ? null
                  : (checked) {
                      setState(() => _attachOrgInvite = checked ?? true);
                    },
              title: const Text('Also send an organization invitation to accept'),
              subtitle: const Text(
                'They still create a password first. Membership is added only '
                'after they Accept in WWJD-DI.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Enter one email per line. Optional display name after a comma '
            '(e.g. jane@school.edu, Jane Smith).',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputController,
            maxLines: 10,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Emails',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : () => _reviewAndSubmit(canRegister: canRegister),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _mode == BulkRosterMode.invite
                        ? 'Review invitation'
                        : 'Review welcome email',
                  ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            Text(
              _result!.mode == 'invite'
                  ? 'Invitation results'
                  : 'Account results',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _ResultsTable(rows: _result!.rows, showPassword: _result!.mode == 'register'),
          ],
        ],
      ),
    );
  }
}

class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.rows, required this.showPassword});

  final List<BulkRosterRow> rows;
  final bool showPassword;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Email')),
          const DataColumn(label: Text('Created')),
          const DataColumn(label: Text('Invited')),
          const DataColumn(label: Text('Email')),
          const DataColumn(label: Text('Skipped')),
          if (showPassword) const DataColumn(label: Text('Temporary password')),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(Text(row.email)),
                DataCell(Text(row.created ? 'Yes' : '—')),
                DataCell(Text(row.invited ? 'Yes' : '—')),
                DataCell(Text(_emailStatus(row))),
                DataCell(Text(row.skipped ? row.skipLabel : '—')),
                if (showPassword)
                  DataCell(
                    SelectableText(
                      row.temporaryPassword ?? '—',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _emailStatus(BulkRosterRow row) {
    if (row.emailSent) return 'Sent';
    if (row.emailFailed) {
      return row.emailError == null || row.emailError!.isEmpty
          ? 'Failed'
          : 'Failed: ${row.emailError}';
    }
    return '—';
  }
}
