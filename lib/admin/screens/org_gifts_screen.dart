import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_providers.dart';
import '../services/group_gift_service.dart';
import '../widgets/admin_rules_debug.dart';

/// How an overall administrator removes a group Gift.
enum AdminGiftDeleteScope { group, organization }

/// Confirm a group-level delete, or an organization-wide delete of the same Gift.
Future<AdminGiftDeleteScope?> showAdminGiftDeleteDialog(
  BuildContext context, {
  required String title,
  required String groupName,
  required String organizationName,
  required bool allowOrganization,
}) {
  return showDialog<AdminGiftDeleteScope>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete this Gift?'),
      content: Text(
        allowOrganization
            ? '“$title” can be removed for $groupName only, or from every '
                'group in $organizationName that has this Gift or a shared copy. '
                'Accepted members lose that copy. Personal Gifts stay private.'
            : '“$title” will be removed for $groupName and for accepted members.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        if (allowOrganization)
          TextButton(
            onPressed: () => Navigator.pop(ctx, AdminGiftDeleteScope.group),
            child: const Text('Delete for this group'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.pop(ctx, AdminGiftDeleteScope.group),
            child: const Text('Delete'),
          ),
        if (allowOrganization)
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, AdminGiftDeleteScope.organization),
            child: const Text('Delete for this organization'),
          ),
      ],
    ),
  );
}

/// Overall administrator list of every group Gift in one organization.
class OrgGiftsScreen extends ConsumerWidget {
  const OrgGiftsScreen({
    super.key,
    required this.orgId,
    required this.organizationName,
  });

  final String orgId;
  final String organizationName;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    OrganizationGiftEntry entry,
  ) async {
    final scope = await showAdminGiftDeleteDialog(
      context,
      title: entry.gift.title,
      groupName: entry.group.name,
      organizationName: organizationName,
      allowOrganization: true,
    );
    if (scope == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(groupGiftServiceProvider);
      if (scope == AdminGiftDeleteScope.organization) {
        final count = await service.deleteGiftAcrossOrganization(
          orgId: orgId,
          gift: entry.gift,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Deleted “${entry.gift.title}” from $count group'
              '${count == 1 ? '' : 's'}.',
            ),
          ),
        );
      } else {
        await service.deleteGift(
          orgId: orgId,
          groupId: entry.group.id,
          giftId: entry.gift.id,
        );
        messenger.showSnackBar(
          SnackBar(content: Text('Deleted “${entry.gift.title}” for ${entry.group.name}.')),
        );
      }
      ref.invalidate(organizationAllGiftsProvider(orgId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverall = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
    final giftsAsync = ref.watch(organizationAllGiftsProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: Text('$organizationName Gifts'),
      ),
      body: !isOverall
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Only an overall administrator can delete organization and group Gifts from here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : giftsAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No organization or group Gifts yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text(
                      'Delete a Gift for one group, or for every group in '
                      '$organizationName that shares it. Personal Gifts are not listed.',
                      style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    for (final entry in entries)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              title: Text(entry.gift.title),
                              subtitle: Text(
                                [
                                  entry.group.name,
                                  entry.gift.frequency,
                                  entry.gift.active ? 'Active' : 'Inactive',
                                  if ((entry.gift.sharedFromGiftId ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    'Shared copy',
                                ].join(' · '),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _delete(context, ref, entry),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AdminRulesDebugText(
                message: 'Could not load organization Gifts:\n$e',
              ),
            ),
    );
  }
}

/// Overall administrator entry to every organization’s group Gifts.
class PlatformGiftsScreen extends ConsumerWidget {
  const PlatformGiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverall = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
    final orgsAsync = ref.watch(userOrganizationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Organization and group Gifts')),
      body: !isOverall
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Only an overall administrator can delete organization and group Gifts.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : orgsAsync.when(
              data: (orgs) {
                if (orgs.isEmpty) {
                  return const Center(child: Text('No organizations yet.'));
                }
                final sorted = [...orgs]
                  ..sort(
                    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Text(
                        'Open an organization to delete a Gift for one group, '
                        'or for every group that shares it.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.45,
                        ),
                      );
                    }
                    final org = sorted[index - 1];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.card_giftcard_outlined),
                        title: Text(org.name),
                        subtitle: const Text('Organization and group Gifts'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrgGiftsScreen(
                                orgId: org.id,
                                organizationName: org.name,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AdminRulesDebugText(
                message: 'Could not load organizations:\n$e',
              ),
            ),
    );
  }
}
