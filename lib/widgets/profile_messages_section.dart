import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin/models/group_membership_invite.dart';
import '../admin/models/organization_invite.dart';
import '../admin/providers/admin_providers.dart';
import '../admin/services/group_invite_service.dart';
import '../admin/services/organization_service.dart';
import '../core/providers/app_providers.dart';

/// Messages under My Profile — organization/group invitations and membership.
class ProfileMessagesSection extends ConsumerStatefulWidget {
  const ProfileMessagesSection({super.key});

  @override
  ConsumerState<ProfileMessagesSection> createState() =>
      _ProfileMessagesSectionState();
}

class _ProfileMessagesSectionState extends ConsumerState<ProfileMessagesSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(pendingOrgInvitesForUserProvider);
      ref.invalidate(pendingGroupInvitesForUserProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orgInvitesAsync = ref.watch(pendingOrgInvitesForUserProvider);
    final groupInvitesAsync = ref.watch(pendingGroupInvitesForUserProvider);
    final membershipsAsync = ref.watch(profileGroupMembershipsProvider);
    final orgService = ref.read(organizationServiceProvider);
    final groupInviteService = ref.read(groupInviteServiceProvider);
    final user = ref.watch(authServiceProvider).currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Messages',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Organization and group invitations, plus your current group membership.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.4),
        ),
        const SizedBox(height: 16),
        Text(
          'Organization invitations',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        orgInvitesAsync.when(
          skipError: true,
          skipLoadingOnReload: true,
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Could not load organization invitations: $e',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          ),
          data: (invites) {
            if (invites.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No pending organization invitations.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final invite in invites) ...[
                  OrgInviteResponseCard(
                    key: ValueKey('org-invite-${invite.id}'),
                    invite: invite,
                    service: orgService,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Group invitations',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        groupInvitesAsync.when(
          skipError: true,
          skipLoadingOnReload: true,
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Could not load group invitations: $e',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          ),
          data: (invites) {
            if (invites.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No pending group invitations.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (kDebugMode && user != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            ref.invalidate(pendingOrgInvitesForUserProvider);
                            ref.invalidate(pendingGroupInvitesForUserProvider);
                          },
                          child: const Text('Refresh invitations'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final invite in invites) ...[
                  GroupInviteResponseCard(
                    invite: invite,
                    service: groupInviteService,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Group membership',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        membershipsAsync.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Could not load group membership: $e',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          ),
          data: (groups) {
            if (groups.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'You are not in any ministry groups yet. Accept an invitation '
                    'above, or ask your organization leader to invite you.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final group in groups)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.groups_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(group.groupName),
                      subtitle: Text(group.userFacingLabel),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Accept / decline card for a pending organization invitation.
class OrgInviteResponseCard extends ConsumerStatefulWidget {
  const OrgInviteResponseCard({
    super.key,
    required this.invite,
    required this.service,
  });

  final OrganizationInvite invite;
  final OrganizationService service;

  @override
  ConsumerState<OrgInviteResponseCard> createState() =>
      _OrgInviteResponseCardState();
}

class _OrgInviteResponseCardState extends ConsumerState<OrgInviteResponseCard> {
  bool _busy = false;

  Future<void> _respond({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action().timeout(const Duration(seconds: 45));
      if (!mounted) return;
      ref.invalidate(pendingOrgInvitesForUserProvider);
      ref.invalidate(profileGroupMembershipsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(successMessage),
        ),
      );
    } catch (e) {
      debugPrint('OrgInviteResponseCard: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_inviteActionError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.apartment_outlined, color: Colors.blue.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    invite.profileOrganizationLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You have been invited to join this organization. '
              'Accept to become a member, or decline if this was sent in error.',
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _respond(
                            action: () => widget.service.declineInvite(invite),
                            successMessage:
                                'Declined the invitation to ${invite.profileOrganizationLabel}.',
                          ),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _respond(
                            action: () => widget.service.acceptInvite(invite),
                            successMessage:
                                'Joined ${invite.profileOrganizationLabel}.',
                          ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _inviteActionError(Object error) {
  if (error is TimeoutException) {
    return 'The invitation request timed out. Check the connection and try again.';
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'This invitation could not be updated. Sign in with the invited '
        'email and try again.';
  }
  return '$error';
}

/// Accept / decline card for a single pending group invitation.
class GroupInviteResponseCard extends StatefulWidget {
  const GroupInviteResponseCard({
    super.key,
    required this.invite,
    required this.service,
  });

  final GroupMembershipInvite invite;
  final GroupInviteService service;

  @override
  State<GroupInviteResponseCard> createState() => _GroupInviteResponseCardState();
}

class _GroupInviteResponseCardState extends State<GroupInviteResponseCard> {
  bool _busy = false;

  Future<void> _respond(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.mail_outline, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    invite.groupName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              invite.organizationName ?? 'Organization group invitation',
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 10),
            Text(
              'You may accept or decline. Membership is never added without your consent.',
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _respond(() => widget.service.rejectInvite(invite)),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _respond(() => widget.service.acceptInvite(invite)),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
