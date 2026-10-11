import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/group_brand_mark.dart';
import '../models/group_gift.dart';
import '../models/ministry_group.dart';
import '../models/organization.dart';
import '../providers/admin_providers.dart';
import '../services/group_gift_service.dart';
import '../widgets/admin_rules_debug.dart';
import '../utils/group_gift_share_access.dart';
import 'create_group_gift_screen.dart';
import 'org_gifts_screen.dart';

/// Lists group-owned My Gifts for a ministry group (org admin / group leader).
class GroupGiftsScreen extends ConsumerWidget {
  const GroupGiftsScreen({
    super.key,
    required this.orgId,
    required this.group,
    required this.organizationName,
  });

  final String orgId;
  final MinistryGroup group;
  final String organizationName;

  Future<void> _openCreate(
    BuildContext context, {
    GroupGift? existing,
  }) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupGiftScreen(
          orgId: orgId,
          group: group,
          organizationName: organizationName,
          existing: existing,
        ),
      ),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Group Gift created for ${group.name}.'
                : 'Group Gift updated.',
          ),
        ),
      );
    }
  }

  Future<void> _shareGift(
    BuildContext context,
    WidgetRef ref,
    GroupGift gift,
  ) async {
    final groups =
        ref.read(organizationGroupsProvider(orgId)).valueOrNull ?? const [];
    final membership =
        ref.read(organizationMembershipProvider(orgId)).valueOrNull;
    final isAdmin = ref.read(isOrganizationAdminProvider(orgId));
    final targets = GroupGiftShareAccess.shareableTargetGroups(
      allGroups: groups,
      sourceGroupId: group.id,
      isOrgAdmin: isAdmin,
      role: membership?.role,
      memberGroupIds: membership?.groupIds ?? const [],
    );

    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _ShareGroupGiftDialog(
        sourceGroupName: group.name,
        targets: targets,
      ),
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;

    final chosen = targets.where((g) => selected.contains(g.id)).toList();
    try {
      final result = await ref.read(groupGiftServiceProvider).shareGiftToGroups(
            gift: gift,
            targetGroups: chosen,
            organizationName: organizationName,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_shareResultMessage(result))),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteGift(
    BuildContext context,
    WidgetRef ref,
    GroupGift gift,
  ) async {
    final isOverall = ref.read(isSuperAdminProvider).valueOrNull ?? false;
    final scope = await showAdminGiftDeleteDialog(
      context,
      title: gift.title,
      groupName: group.name,
      organizationName: organizationName,
      allowOrganization: isOverall,
    );
    if (scope == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(groupGiftServiceProvider);
      if (scope == AdminGiftDeleteScope.organization) {
        final count = await service.deleteGiftAcrossOrganization(
          orgId: orgId,
          gift: gift,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Deleted “${gift.title}” from $count group'
              '${count == 1 ? '' : 's'}.',
            ),
          ),
        );
      } else {
        await service.deleteGift(
          orgId: orgId,
          groupId: group.id,
          giftId: gift.id,
        );
        messenger.showSnackBar(
          SnackBar(content: Text('Deleted “${gift.title}”.')),
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

  static String _shareResultMessage(GroupGiftShareResult result) {
    if (result.sharedCount == 0 && result.skippedCount > 0) {
      return 'Already shared with ${result.skippedGroupNames.join(', ')}.';
    }
    if (result.skippedCount == 0) {
      return 'Shared with ${result.sharedGroupNames.join(', ')}.';
    }
    return 'Shared with ${result.sharedGroupNames.join(', ')}. '
        'Already on ${result.skippedGroupNames.join(', ')}.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage =
        ref.watch(canManageGroupGiftsProvider((orgId, group.id)));
    final giftsAsync =
        ref.watch(organizationGroupGiftsProvider((orgId, group.id)));
    final orgLogo = Organization.resolveLogoUrl(
      organizationLogoUrl:
          ref.watch(organizationProvider(orgId)).valueOrNull?.resolvedLogoUrl,
      fallback: group.logoUrl,
    );

    if (!canManage) {
      return Scaffold(
        appBar: AppBar(title: Text('${group.name} Gifts')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only organization administrators and leaders of this group '
              'can create or share group-branded My Gifts activities.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${group.name} Gifts'),
            const Text(
              'Shared My Gifts for accepted members',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: giftsAsync.when(
        data: (gifts) {
          if (gifts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GroupBrandMark(
                      groupName: group.name,
                      logoUrl: orgLogo,
                      orgId: orgId,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No group Gifts yet.\n\n'
                      'Create a branded activity for accepted ${group.name} '
                      'members. It appears in their Sharing My Gifts list.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (gifts.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'Drag the handle to reorder. Accepted members see this order.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
              Expanded(
                child: _ReorderableGroupGifts(
                  gifts: gifts,
                  group: group,
                  orgId: orgId,
                  orgLogo: orgLogo,
                  onOpen: (gift) => _openCreate(context, existing: gift),
                  onShare: (gift) => _shareGift(context, ref, gift),
                  onActive: (gift, on) async {
                    try {
                      await ref.read(groupGiftServiceProvider).setActive(
                            gift: gift,
                            active: on,
                          );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                  onReorder: (orderedIds) {
                    return ref.read(groupGiftServiceProvider).reorderGifts(
                          orgId: orgId,
                          groupId: group.id,
                          orderedIds: orderedIds,
                        );
                  },
                  onDelete: (gift) => _confirmDeleteGift(context, ref, gift),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AdminRulesDebugText(
          message: 'Could not load group gifts:\n$e',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('Create group Gift'),
      ),
    );
  }
}

class _ReorderableGroupGifts extends StatefulWidget {
  const _ReorderableGroupGifts({
    required this.gifts,
    required this.group,
    required this.orgId,
    required this.orgLogo,
    required this.onOpen,
    required this.onShare,
    required this.onActive,
    required this.onReorder,
    required this.onDelete,
  });

  final List<GroupGift> gifts;
  final MinistryGroup group;
  final String orgId;
  final String? orgLogo;
  final void Function(GroupGift gift) onOpen;
  final void Function(GroupGift gift) onShare;
  final Future<void> Function(GroupGift gift, bool active) onActive;
  final Future<void> Function(List<String> orderedIds) onReorder;
  final void Function(GroupGift gift) onDelete;

  @override
  State<_ReorderableGroupGifts> createState() => _ReorderableGroupGiftsState();
}

class _ReorderableGroupGiftsState extends State<_ReorderableGroupGifts> {
  List<GroupGift>? _pending;

  @override
  void didUpdateWidget(covariant _ReorderableGroupGifts oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = _pending;
    if (pending == null) return;
    final incoming = widget.gifts.map((gift) => gift.id).join(',');
    final local = pending.map((gift) => gift.id).join(',');
    if (incoming == local) _pending = null;
  }

  @override
  Widget build(BuildContext context) {
    final gifts = _pending ?? widget.gifts;
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      buildDefaultDragHandles: false,
      itemCount: gifts.length,
      onReorderItem: (oldIndex, newIndex) async {
        if (oldIndex == newIndex) return;
        final next = [...gifts];
        final moved = next.removeAt(oldIndex);
        next.insert(newIndex, moved);
        final messenger = ScaffoldMessenger.of(context);
        setState(() => _pending = next);
        try {
          await widget.onReorder(next.map((gift) => gift.id).toList());
        } catch (e) {
          if (!mounted) return;
          setState(() => _pending = null);
          messenger.showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      },
      itemBuilder: (context, index) {
        final gift = gifts[index];
        return Card(
          key: ValueKey(gift.id),
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
                title: Row(
                  children: [
                    GroupBrandMark(
                      groupName: widget.group.name,
                      logoUrl: Organization.resolveLogoUrl(
                        organizationLogoUrl: widget.orgLogo,
                        fallback: gift.logoUrl,
                      ),
                      orgId: widget.orgId,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(gift.title)),
                  ],
                ),
                subtitle: Text(
                  [
                    gift.frequency,
                    if (gift.specificTime != null &&
                        gift.specificTime!.isNotEmpty)
                      gift.specificTime!,
                  ].join(' · '),
                ),
                onTap: () => widget.onOpen(gift),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => widget.onDelete(gift),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                    TextButton.icon(
                      onPressed: () => widget.onShare(gift),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(gift.active ? 'Active' : 'Inactive'),
                        Switch(
                          value: gift.active,
                          onChanged: (on) => widget.onActive(gift, on),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShareGroupGiftDialog extends StatefulWidget {
  const _ShareGroupGiftDialog({
    required this.sourceGroupName,
    required this.targets,
  });

  final String sourceGroupName;
  final List<MinistryGroup> targets;

  @override
  State<_ShareGroupGiftDialog> createState() => _ShareGroupGiftDialogState();
}

class _ShareGroupGiftDialogState extends State<_ShareGroupGiftDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share to other groups'),
      content: SizedBox(
        width: 420,
        child: widget.targets.isEmpty
            ? const Text(
                'No other groups in this organization are available. '
                'Organization administrators can share to any group. '
                'Group leaders can share only to groups they lead.',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Copy this Gift from ${widget.sourceGroupName} to selected '
                    'groups. Accepted members of those groups receive their own '
                    'copy. Personal conversations stay private.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final group in widget.targets)
                          CheckboxListTile(
                            value: _selected.contains(group.id),
                            title: Text(group.name),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (on) {
                              setState(() {
                                if (on == true) {
                                  _selected.add(group.id);
                                } else {
                                  _selected.remove(group.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.targets.isNotEmpty)
          FilledButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, Set<String>.from(_selected)),
            child: const Text('Share'),
          ),
      ],
    );
  }
}
