import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin/providers/admin_providers.dart';
import '../screens/edit_profile_screen.dart';
import 'profile_messages_section.dart';

/// Home-screen invitations — org and group invites with accept / decline.
class HomePendingInvitesSection extends ConsumerStatefulWidget {
  const HomePendingInvitesSection({super.key});

  @override
  ConsumerState<HomePendingInvitesSection> createState() =>
      _HomePendingInvitesSectionState();
}

class _HomePendingInvitesSectionState extends ConsumerState<HomePendingInvitesSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshInvites());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshInvites();
    }
  }

  void _refreshInvites() {
    if (!mounted) return;
    ref.invalidate(pendingOrgInvitesForUserProvider);
    ref.invalidate(pendingGroupInvitesForUserProvider);
  }

  void _openMyProfile() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgInvitesAsync = ref.watch(pendingOrgInvitesForUserProvider);
    final groupInvitesAsync = ref.watch(pendingGroupInvitesForUserProvider);
    final orgService = ref.read(organizationServiceProvider);
    final groupInviteService = ref.read(groupInviteServiceProvider);

    final orgInvites = orgInvitesAsync.valueOrNull ?? const [];
    final groupInvites = groupInvitesAsync.valueOrNull ?? const [];
    final totalCount = orgInvites.length + groupInvites.length;

    final isInitialLoad =
        (orgInvitesAsync.isLoading && !orgInvitesAsync.hasValue) ||
        (groupInvitesAsync.isLoading && !groupInvitesAsync.hasValue);

    if (isInitialLoad) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    if (orgInvitesAsync.hasError || groupInvitesAsync.hasError) {
      final error = orgInvitesAsync.error ?? groupInvitesAsync.error;
      debugPrint('HomePendingInvitesSection: $error');
      if (!kDebugMode) return const SizedBox.shrink();
      return Material(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Invitations could not load: $error',
            style: TextStyle(color: Colors.red.shade900),
          ),
        ),
      );
    }

    if (totalCount == 0) return const SizedBox.shrink();

    return Material(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notifications_active_outlined,
                    color: Colors.amber.shade900, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invitations waiting',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _summary(orgCount: orgInvites.length, groupCount: groupInvites.length),
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Badge(
                  label: Text('$totalCount'),
                  child: Icon(Icons.mail_outline, color: Colors.amber.shade900),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final invite in orgInvites) ...[
              OrgInviteResponseCard(
                key: ValueKey('home-org-invite-${invite.id}'),
                invite: invite,
                service: orgService,
              ),
              const SizedBox(height: 8),
            ],
            for (final invite in groupInvites) ...[
              GroupInviteResponseCard(
                invite: invite,
                service: groupInviteService,
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _openMyProfile,
                child: const Text('View all in My Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _summary({required int orgCount, required int groupCount}) {
    if (orgCount > 0 && groupCount > 0) {
      return 'Accept or decline your organization and group invitations below.';
    }
    if (orgCount > 0) {
      return orgCount == 1
          ? 'Accept or decline your organization invitation below.'
          : 'Accept or decline your organization invitations below.';
    }
    return groupCount == 1
        ? 'Accept or decline your group invitation below.'
        : 'Accept or decline your group invitations below.';
  }
}

/// @deprecated Use [HomePendingInvitesSection].
typedef PendingGroupInvitesBanner = HomePendingInvitesSection;
