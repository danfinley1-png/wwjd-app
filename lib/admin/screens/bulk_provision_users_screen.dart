import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_providers.dart';
import '../services/platform_admin_service.dart';

/// Bulk email upload for institutional user provisioning.
class BulkProvisionUsersScreen extends ConsumerStatefulWidget {
  const BulkProvisionUsersScreen({super.key, required this.orgId});

  final String orgId;

  @override
  ConsumerState<BulkProvisionUsersScreen> createState() =>
      _BulkProvisionUsersScreenState();
}

class _BulkProvisionUsersScreenState extends ConsumerState<BulkProvisionUsersScreen> {
  final _inputController = TextEditingController();
  bool _busy = false;
  ProvisionUsersResult? _result;
  String? _error;

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

  Future<void> _submit() async {
    final entries = _parseInput();
    if (entries.isEmpty) {
      setState(() => _error = 'Enter at least one email (one per line).');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await ref.read(userProvisioningServiceProvider).provisionUsers(
            orgId: widget.orgId,
            users: entries,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk add users')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Enter one email per line. Optional display name after a comma '
            '(e.g. jane@school.edu, Jane Smith).',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 8),
          const Text(
            'New accounts receive a temporary password shown once below. '
            'Users must set a new password on first sign-in.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _inputController,
            maxLines: 12,
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
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create accounts'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            Text(
              'Created ${_result!.created.length} account(s)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_result!.created.isNotEmpty)
              for (final account in _result!.created)
                Card(
                  child: ListTile(
                    title: Text(account.email),
                    subtitle: Text(
                      [
                        if (account.welcomeEmailSent)
                          'Welcome email sent.'
                        else if (account.welcomeEmailError != null)
                          'Welcome email could not be sent: ${account.welcomeEmailError}'
                        else
                          'Welcome email not sent (check email configuration).',
                        'Temporary password: ${account.temporaryPassword}',
                        'Share the password securely if the welcome email did not arrive.',
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                  ),
                ),
            if (_result!.skipped.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Skipped: ${_result!.skipped.join(', ')}'),
            ],
          ],
        ],
      ),
    );
  }
}
