// lib/screens/sharing_my_gifts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../core/catholic_prayers/prayer_gift_link.dart';
import '../core/gift_list_filter.dart';
import '../core/gift_tracking.dart';
import '../core/gift_reminder_utils.dart';
import '../core/group_practice_tracking.dart';
import '../core/mobile_touch.dart';
import '../core/providers/app_providers.dart';
import '../core/services/gift_service.dart';
import '../core/services/group_practice_service.dart';
import '../core/responsive_layout.dart';
import '../admin/models/organization.dart';
import '../admin/providers/admin_providers.dart';
import '../create_activity_dialog.dart';
import '../models/gift_activity.dart';
import '../models/gift_status.dart';
import '../models/group_practice_instance.dart';
import '../widgets/auth_layout.dart';
import '../widgets/share_actions_bar.dart';
import '../widgets/group_brand_mark.dart';
import '../widgets/profile_avatar.dart';
import 'activity_detail_screen.dart';
import 'group_practice_detail_screen.dart';

class SharingMyGiftsScreen extends ConsumerStatefulWidget {
  const SharingMyGiftsScreen({super.key});

  @override
  ConsumerState<SharingMyGiftsScreen> createState() =>
      _SharingMyGiftsScreenState();
}

class _SharingMyGiftsScreenState extends ConsumerState<SharingMyGiftsScreen> {
  GiftFilterKind _filterKind = GiftFilterKind.all;
  String? _filterOrgId;
  String? _filterGroupId;

  GiftListFilter get _filter {
    switch (_filterKind) {
      case GiftFilterKind.all:
        return const GiftListFilter.all();
      case GiftFilterKind.personal:
        return const GiftListFilter.personal();
      case GiftFilterKind.organization:
        return GiftListFilter.organization(_filterOrgId ?? '');
      case GiftFilterKind.group:
        return GiftListFilter.group(_filterGroupId ?? '');
    }
  }
  void _openCreateActivityDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => CreateActivityDialog(
        onActivityCreated: () {},
      ),
    );
  }

  Future<void> _completeGift(GiftActivity activity) async {
    final giftService = ref.read(giftServiceProvider);
    try {
      final updated = await giftService.completeGiftForToday(activity);
      if (!mounted) return;

      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Already ${GiftTracking.completedStatusLabel(activity).toLowerCase()}',
            ),
          ),
        );
        return;
      }

      final streakLine = updated.currentStreak > 1
          ? ' · ${updated.currentStreak}-day streak!'
          : updated.currentStreak == 1
              ? ' · Streak started!'
              : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${GiftTracking.completedStatusLabel(updated)}$streakLine',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save completion: $e')),
        );
      }
    }
  }

  Future<void> _completeGroupPractice(GroupPracticeInstance practice) async {
    try {
      final updated = await ref
          .read(groupPracticeServiceProvider)
          .completeNextSlot(practice);
      if (!mounted) return;

      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All slots complete for today.')),
        );
        return;
      }

      final streakLine = updated.currentStreak > 1
          ? ' · ${updated.currentStreak}-day streak!'
          : updated.currentStreak == 1
              ? ' · Streak started!'
              : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group practice complete$streakLine'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save completion: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final giftsAsync = ref.watch(userGiftsStreamProvider);
    final practicesAsync = ref.watch(userGroupPracticesStreamProvider);
    final giftService = ref.watch(giftServiceProvider);
    final groupPracticeService = ref.watch(groupPracticeServiceProvider);
    final compact = isCompactWidth(context);
    final fabClearance =
        kMinTouchTarget + MediaQuery.viewPaddingOf(context).bottom + 16;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sharing My Gifts'),
        centerTitle: true,
      ),
      body: giftsAsync.when(
        loading: () => practicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (_) => const Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error loading gifts:\n$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
        data: (activities) {
          return practicesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Error loading group practices: $err'),
            ),
            data: (groupPractices) {
              final filter = _filter;
              return _buildBody(
              context,
              activities: filter.applyToGifts(activities),
              groupPractices: filter.applyToPractices(groupPractices),
              giftService: giftService,
              groupPracticeService: groupPracticeService,
              fabClearance: fabClearance,
              unfilteredEmpty: activities.isEmpty && groupPractices.isEmpty,
            );
            },
          );
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom),
        child: compact
            ? FloatingActionButton(
                onPressed: _openCreateActivityDialog,
                tooltip: 'Add an Activity',
                child: const Icon(Icons.add),
              )
            : FloatingActionButton.extended(
                onPressed: _openCreateActivityDialog,
                label: const Text('Add an Activity'),
                icon: const Icon(Icons.add),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<GiftActivity> activities,
    required List<GroupPracticeInstance> groupPractices,
    required GiftService giftService,
    required GroupPracticeService groupPracticeService,
    required double fabClearance,
    required bool unfilteredEmpty,
  }) {
    final orgs =
        ref.watch(memberOrganizationsProvider).valueOrNull ?? const [];
    final groups =
        ref.watch(profileGroupMembershipsProvider).valueOrNull ?? const [];
    final orgLogos = {
      for (final org in orgs) org.id: org.resolvedLogoUrl,
    };
    final profile = ref.watch(userProfileStreamProvider).valueOrNull;
    final userPhotoUrl = profile?.photoUrl;
    final photoCacheBustMs = profile?.updatedAt?.millisecondsSinceEpoch;

    if (_filterKind == GiftFilterKind.organization &&
        _filterOrgId == null &&
        orgs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _filterOrgId == null && orgs.isNotEmpty) {
          setState(() => _filterOrgId = orgs.first.id);
        }
      });
    }
    if (_filterKind == GiftFilterKind.group &&
        _filterGroupId == null &&
        groups.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _filterGroupId == null && groups.isNotEmpty) {
          setState(() => _filterGroupId = groups.first.groupId);
        }
      });
    }

    final filterBar = _GiftsFilterBar(
      kind: _filterKind,
      organizationId: _filterOrgId,
      groupId: _filterGroupId,
      organizations: [
        for (final org in orgs) (id: org.id, name: org.name),
      ],
      groups: [
        for (final g in groups)
          (id: g.groupId, name: g.userFacingLabel),
      ],
      onKindChanged: (kind) {
        setState(() {
          _filterKind = kind;
          if (kind == GiftFilterKind.organization &&
              _filterOrgId == null &&
              orgs.isNotEmpty) {
            _filterOrgId = orgs.first.id;
          }
          if (kind == GiftFilterKind.group &&
              _filterGroupId == null &&
              groups.isNotEmpty) {
            _filterGroupId = groups.first.groupId;
          }
        });
      },
      onOrganizationChanged: (id) => setState(() {
        _filterKind = GiftFilterKind.organization;
        _filterOrgId = id;
      }),
      onGroupChanged: (id) => setState(() {
        _filterKind = GiftFilterKind.group;
        _filterGroupId = id;
      }),
    );

    if (unfilteredEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, fabClearance),
        children: [
          filterBar,
          const SizedBox(height: 48),
          const Icon(Icons.card_giftcard, size: 80, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'No activities yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to add one, or use Add to My Gifts Plan from chat.\n'
            'Group Gifts from your organization appear here too.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    if (activities.isEmpty && groupPractices.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, fabClearance),
        children: [
          filterBar,
          const SizedBox(height: 48),
          const Icon(Icons.filter_alt_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No gifts match this filter',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ],
      );
    }

    final stats = giftService.getAggregateStats(activities);
    final todaySectionGifts = giftService.getTodaySectionGifts(activities);
    final dueGroupPractices = groupPracticeService.getDueToday(groupPractices);
    final activeGifts = giftService.getActiveGifts(activities);
    final activeGroupPractices =
        GroupPracticeTracking.activePractices(groupPractices);

    final dueCount = todaySectionGifts.length + dueGroupPractices.length;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, fabClearance),
      children: [
        filterBar,
        const SizedBox(height: 16),
        _StatsHeader(stats: stats, groupDueCount: dueGroupPractices.length),
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'Due Now',
          subtitle: dueCount == 0
              ? 'All caught up for now'
              : '$dueCount item${dueCount == 1 ? '' : 's'} due',
          icon: Icons.today,
        ),
        const SizedBox(height: 8),
        if (dueCount == 0)
          const _EmptySectionCard(
            message: 'All caught up for now. Peace be with you.',
          )
        else ...[
          ...todaySectionGifts.map(
            (gift) => _GiftCard(
              gift: gift,
              brandLogoUrl: Organization.resolveLogoUrl(
                organizationLogoUrl: gift.organizationId == null
                    ? null
                    : orgLogos[gift.organizationId],
                fallback: gift.groupLogoUrl,
              ),
              userPhotoUrl: userPhotoUrl,
              photoCacheBustMs: photoCacheBustMs,
              giftService: giftService,
              onComplete: () => _completeGift(gift),
              onRemove: () => _confirmRemove(gift),
              highlightDueToday: true,
              showCompleteCheckbox: true,
            ),
          ),
          ...dueGroupPractices.map(
            (practice) => _GroupPracticeCard(
              practice: practice,
              highlightDue: true,
              showCompleteCheckbox: true,
              onComplete: () => _completeGroupPractice(practice),
            ),
          ),
        ],
        if (activeGroupPractices.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Group Practices',
            subtitle: '${activeGroupPractices.length} from your groups',
            icon: Icons.groups_outlined,
          ),
          const SizedBox(height: 8),
          ...activeGroupPractices.map(
            (practice) => _GroupPracticeCard(
              practice: practice,
              highlightDue: dueGroupPractices.any((d) => d.id == practice.id),
              showCompleteCheckbox: false,
              onComplete: () => _completeGroupPractice(practice),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Active Gifts',
          subtitle: '${activeGifts.length} in your plan',
          icon: Icons.favorite_outline,
        ),
        const SizedBox(height: 8),
        if (activeGifts.isEmpty)
          const _EmptySectionCard(
            message:
                'No active gifts. Completed or paused items are hidden here.',
          )
        else ...[
          ...activeGifts.map(
            (gift) => _GiftCard(
              gift: gift,
              brandLogoUrl: Organization.resolveLogoUrl(
                organizationLogoUrl: gift.organizationId == null
                    ? null
                    : orgLogos[gift.organizationId],
                fallback: gift.groupLogoUrl,
              ),
              userPhotoUrl: userPhotoUrl,
              photoCacheBustMs: photoCacheBustMs,
              giftService: giftService,
              onComplete: () => _completeGift(gift),
              onRemove: () => _confirmRemove(gift),
              highlightDueToday:
                  todaySectionGifts.any((t) => t.id == gift.id),
              showCompleteCheckbox: false,
            ),
          ),
        ],
        if (_completedOrPaused(activities).isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Completed & Paused',
            subtitle: '${_completedOrPaused(activities).length} items',
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 8),
          ..._completedOrPaused(activities).map(
            (gift) => _CompletedGiftTile(
              gift: gift,
              giftService: giftService,
              userPhotoUrl: userPhotoUrl,
              photoCacheBustMs: photoCacheBustMs,
              brandLogoUrl: Organization.resolveLogoUrl(
                organizationLogoUrl: gift.organizationId == null
                    ? null
                    : orgLogos[gift.organizationId],
                fallback: gift.groupLogoUrl,
              ),
              onRemove: () => _confirmRemove(gift),
            ),
          ),
        ],
      ],
    );
  }

  List<GiftActivity> _completedOrPaused(List<GiftActivity> gifts) {
    return gifts
        .where(
          (g) =>
              g.status == GiftStatus.completed || g.status == GiftStatus.paused,
        )
        .toList();
  }

  Future<void> _confirmRemove(GiftActivity activity) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => ResponsiveAuthDialog(
        title: const Text('Remove Activity?'),
        content: Text(
          'What would you like to do with "${activity.title}"?',
        ),
        actions: AuthDialogActions(
          actions: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'history'),
              icon: const Icon(Icons.history),
              label: const Text('Move to My History'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Permanently'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    try {
      if (choice == 'history') {
        final added = await ref.read(giftServiceProvider).moveToHistory(
              activity,
              ref.read(historyServiceProvider),
            );
        await ref.read(sessionHistoryProvider.notifier).loadSessionFromFirebase();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                added
                    ? 'Moved to My History'
                    : 'Removed from gifts (already in My History)',
              ),
            ),
          );
        }
      } else if (choice == 'delete') {
        await ref.read(giftServiceProvider).deleteGift(activity.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activity deleted permanently')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove activity: $e')),
        );
      }
    }
  }
}

class _StatsHeader extends StatelessWidget {
  final GiftAggregateStats stats;
  final int groupDueCount;

  const _StatsHeader({
    required this.stats,
    this.groupDueCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.parchmentDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: _StatChip(
                label: 'Due now',
                value: groupDueCount > 0
                    ? '${stats.completedTodayCount}/${stats.dueTodayCount + groupDueCount}'
                    : '${stats.completedTodayCount}/${stats.dueTodayCount}',
                icon: Icons.check_circle_outline,
              ),
            ),
            Expanded(
              child: _StatChip(
                label: 'Total',
                value: '${stats.totalCompletions}',
                icon: Icons.auto_awesome,
              ),
            ),
            Expanded(
              child: _StatChip(
                label: 'Best streak',
                value: stats.bestStreak > 0 ? '${stats.bestStreak}d' : '—',
                icon: Icons.local_fire_department_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryMaroon),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryMaroon, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  final String message;

  const _EmptySectionCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  final GiftActivity gift;
  final GiftService giftService;
  final VoidCallback onComplete;
  final VoidCallback onRemove;
  final bool highlightDueToday;
  final bool showCompleteCheckbox;
  final String? brandLogoUrl;
  final String? userPhotoUrl;
  final int? photoCacheBustMs;

  const _GiftCard({
    required this.gift,
    required this.giftService,
    required this.onComplete,
    required this.onRemove,
    this.highlightDueToday = false,
    this.showCompleteCheckbox = false,
    this.brandLogoUrl,
    this.userPhotoUrl,
    this.photoCacheBustMs,
  });

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(
          activity: gift,
          onUpdate: (updated) {
            giftService.saveGift(updated);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doneInPeriod = GiftTracking.isCompletedInPeriod(gift);
    final dueLabel = GiftTracking.dueStatusLabel(gift);
    final completeLabel = GiftTracking.completeActionLabel(gift);
    final isDue = GiftTracking.isDue(gift);
    final description = gift.description.trim();

    Widget leading;
    if (showCompleteCheckbox) {
      leading = SizedBox(
        width: touchTargetMin(context),
        height: touchTargetMin(context),
        child: Checkbox(
          value: doneInPeriod,
          onChanged: doneInPeriod ? null : (_) => onComplete(),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      );
    } else if (gift.isGroupGift) {
      leading = GroupBrandMark(
        groupName: gift.brandLabel,
        logoUrl: brandLogoUrl ?? gift.groupLogoUrl,
        orgId: gift.organizationId,
      );
    } else {
      leading = _UserGiftAvatar(
        photoUrl: userPhotoUrl,
        cacheBustMs: photoCacheBustMs,
        radius: 20,
      );
    }

    final meta = [
      if (gift.isGroupGift) gift.brandLabel,
      gift.frequency,
      if (!gift.isGroupGift && gift.currentStreak > 0)
        '${gift.currentStreak}-day streak',
      if (gift.totalCompletions > 0)
        '${gift.totalCompletions} completion${gift.totalCompletions == 1 ? '' : 's'}',
      if (dueLabel.isNotEmpty) dueLabel,
      if (gift.hasReminder && gift.specificTime != null)
        'Reminder: ${GiftReminderUtils.formatDisplayTime(gift.specificTime)}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: showCompleteCheckbox && doneInPeriod
          ? AppColors.success.withValues(alpha: 0.08)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlightDueToday && isDue
            ? BorderSide(color: AppColors.gold.withValues(alpha: 0.6))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (showCompleteCheckbox && gift.isGroupGift) ...[
                              GroupBrandMark(
                                groupName: gift.brandLabel,
                                logoUrl: brandLogoUrl ?? gift.groupLogoUrl,
                                orgId: gift.organizationId,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (showCompleteCheckbox && !gift.isGroupGift) ...[
                              _UserGiftAvatar(
                                photoUrl: userPhotoUrl,
                                cacheBustMs: photoCacheBustMs,
                                radius: 14,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                gift.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: showCompleteCheckbox &&
                                          doneInPeriod
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
          if (isDue && !doneInPeriod)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check),
                  label: Text(completeLabel),
                  style: mobileTextButtonStyle(context),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 12),
            child: ShareActionsBar(
              question: gift.shareQuestion,
              response: gift.shareBody,
              title: gift.title,
              giftDescription: gift.description,
              linkedActivityId: gift.id,
              linkedPrayerId: PrayerGiftLink.resolvePrayerId(gift),
              isGiftActivity: true,
              onDelete: onRemove,
              deleteTooltip: 'Remove activity',
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupPracticeCard extends StatelessWidget {
  final GroupPracticeInstance practice;
  final bool highlightDue;
  final bool showCompleteCheckbox;
  final VoidCallback onComplete;

  const _GroupPracticeCard({
    required this.practice,
    required this.onComplete,
    this.highlightDue = false,
    this.showCompleteCheckbox = false,
  });

  @override
  Widget build(BuildContext context) {
    final summary = GroupPracticeTracking.timesSummary(practice);
    final dueNow = GroupPracticeTracking.isDueNow(practice);
    final nextSlot = GroupPracticeTracking.nextDueSlotLabel(practice);
    final todaySlots = GroupPracticeTracking.slotsForDate(
      practice,
      DateTime.now(),
    );
    final allTodayDone =
        !dueNow && todaySlots.isNotEmpty && todaySlots.every(practice.completionSlots.contains);

    Widget leading;
    if (showCompleteCheckbox) {
      leading = SizedBox(
        width: touchTargetMin(context),
        height: touchTargetMin(context),
        child: Checkbox(
          value: allTodayDone,
          onChanged: allTodayDone ? null : (_) => onComplete(),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      );
    } else {
      leading = const Icon(Icons.groups_outlined, color: AppColors.primaryMaroon);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlightDue && dueNow
            ? BorderSide(color: AppColors.gold.withValues(alpha: 0.6))
            : BorderSide.none,
      ),
      child: ListTile(
        leading: leading,
        title: Text(
          practice.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        isThreeLine: practice.description.trim().isNotEmpty,
        subtitle: Text(
          [
            if (practice.groupName != null) practice.groupName!,
            summary,
            if (dueNow) 'Due: $nextSlot',
            if (practice.description.trim().isNotEmpty)
              practice.description.trim(),
          ].join('\n'),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: dueNow
            ? TextButton(
                onPressed: onComplete,
                child: const Text('Complete'),
              )
            : const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupPracticeDetailScreen(practice: practice),
            ),
          );
        },
      ),
    );
  }
}

class _UserGiftAvatar extends StatelessWidget {
  const _UserGiftAvatar({
    required this.photoUrl,
    required this.radius,
    this.cacheBustMs,
  });

  final String? photoUrl;
  final double radius;
  final int? cacheBustMs;

  @override
  Widget build(BuildContext context) {
    return ProfileAvatar(
      photoUrl: photoUrl,
      radius: radius,
      cacheBustMs: cacheBustMs,
      loadFromStorageWhenEmpty: true,
    );
  }
}

class _CompletedGiftTile extends StatelessWidget {
  final GiftActivity gift;
  final GiftService giftService;
  final VoidCallback onRemove;
  final String? brandLogoUrl;
  final String? userPhotoUrl;
  final int? photoCacheBustMs;

  const _CompletedGiftTile({
    required this.gift,
    required this.giftService,
    required this.onRemove,
    this.brandLogoUrl,
    this.userPhotoUrl,
    this.photoCacheBustMs,
  });

  @override
  Widget build(BuildContext context) {
    final description = gift.description.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: gift.isGroupGift
            ? GroupBrandMark(
                groupName: gift.brandLabel,
                logoUrl: brandLogoUrl ?? gift.groupLogoUrl,
                orgId: gift.organizationId,
                size: 36,
              )
            : _UserGiftAvatar(
                photoUrl: userPhotoUrl,
                cacheBustMs: photoCacheBustMs,
                radius: 18,
              ),
        title: Text(
          gift.title,
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
        isThreeLine: description.isNotEmpty,
        subtitle: Text(
          [
            if (gift.isGroupGift) gift.brandLabel,
            gift.status.firestoreValue,
            if (description.isNotEmpty) description,
          ].join('\n'),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemove,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ActivityDetailScreen(
                activity: gift,
                onUpdate: (updated) {
                  giftService.saveGift(updated);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GiftsFilterBar extends StatelessWidget {
  const _GiftsFilterBar({
    required this.kind,
    required this.organizationId,
    required this.groupId,
    required this.organizations,
    required this.groups,
    required this.onKindChanged,
    required this.onOrganizationChanged,
    required this.onGroupChanged,
  });

  final GiftFilterKind kind;
  final String? organizationId;
  final String? groupId;
  final List<({String id, String name})> organizations;
  final List<({String id, String name})> groups;
  final ValueChanged<GiftFilterKind> onKindChanged;
  final ValueChanged<String> onOrganizationChanged;
  final ValueChanged<String> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: kind == GiftFilterKind.all,
              onSelected: (_) => onKindChanged(GiftFilterKind.all),
            ),
            ChoiceChip(
              label: const Text('Personal'),
              selected: kind == GiftFilterKind.personal,
              onSelected: (_) => onKindChanged(GiftFilterKind.personal),
            ),
            if (organizations.isNotEmpty)
              ChoiceChip(
                label: const Text('By Organization'),
                selected: kind == GiftFilterKind.organization,
                onSelected: (_) =>
                    onKindChanged(GiftFilterKind.organization),
              ),
            if (groups.isNotEmpty)
              ChoiceChip(
                label: const Text('By Group'),
                selected: kind == GiftFilterKind.group,
                onSelected: (_) => onKindChanged(GiftFilterKind.group),
              ),
          ],
        ),
        if (kind == GiftFilterKind.organization && organizations.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: organizations.any((o) => o.id == organizationId)
                ? organizationId
                : organizations.first.id,
            decoration: const InputDecoration(
              labelText: 'Organization',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final org in organizations)
                DropdownMenuItem(value: org.id, child: Text(org.name)),
            ],
            onChanged: (id) {
              if (id != null) onOrganizationChanged(id);
            },
          ),
        ],
        if (kind == GiftFilterKind.group && groups.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: groups.any((g) => g.id == groupId)
                ? groupId
                : groups.first.id,
            decoration: const InputDecoration(
              labelText: 'Group',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final group in groups)
                DropdownMenuItem(value: group.id, child: Text(group.name)),
            ],
            onChanged: (id) {
              if (id != null) onGroupChanged(id);
            },
          ),
        ],
      ],
    );
  }
}
