import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_role.dart';
import '../providers/admin_providers.dart';

class InviteMembersScreen extends ConsumerStatefulWidget {
  const InviteMembersScreen({
    super.key,
    required this.orgId,
  });

  final String orgId;

  @override
  ConsumerState<InviteMembersScreen> createState() =>
      _InviteMembersScreenState();
}

class _InviteMembersScreenState extends ConsumerState<InviteMembersScreen> {
  final _emailController = TextEditingController();
  AdminRole _role = AdminRole.member;
  final Set<String> _selectedGroupIds = {};
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(organizationServiceProvider).createInvite(
            orgId: widget.orgId,
            email: _emailController.text,
            role: _role,
            groupIds: _selectedGroupIds.toList(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 4),
          content: Text('Invitation sent'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(organizationGroupsProvider(widget.orgId));

    return Scaffold(
      appBar: AppBar(title: const Text('Invite member')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Organization administrator invitations require an organization '
            'administrator account. Group leaders may invite members or other '
            'group leaders.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.45),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AdminRole>(
            value: _role,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: AdminRole.values
                .map(
                  (role) => DropdownMenuItem(
                    value: role,
                    child: Text(role.label),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _role = value);
                  },
          ),
          const SizedBox(height: 16),
          Text(
            'Assign to groups (optional)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Create groups first to assign members.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                );
              }
              return Column(
                children: [
                  for (final group in groups)
                    CheckboxListTile(
                      value: _selectedGroupIds.contains(group.id),
                      onChanged: _saving
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
                      subtitle: group.ageBand != null ? Text(group.ageBand!) : null,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Text('$e'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _sendInvite,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send invitation'),
          ),
        ],
      ),
    );
  }
}
