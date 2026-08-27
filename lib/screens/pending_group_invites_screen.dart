import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin/providers/admin_providers.dart';
import '../admin/services/group_invite_service.dart';
import '../widgets/profile_messages_section.dart';

/// User consent flow for group membership invitations.
class PendingGroupInvitesScreen extends ConsumerWidget {
  const PendingGroupInvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(pendingGroupInvitesForUserProvider);
    final service = ref.read(groupInviteServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Group invitations')),
      body: invitesAsync.when(
        data: (invites) {
          if (invites.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No pending group invitations.'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final invite = invites[index];
              return GroupInviteResponseCard(
                invite: invite,
                service: service,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
