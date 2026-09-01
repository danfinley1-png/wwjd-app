// lib/screens/sharing_my_gifts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin/models/organization.dart';
import '../admin/models/service_hours.dart';
import '../admin/providers/admin_providers.dart';
import '../core/app_colors.dart';
import '../core/gift_list_filter.dart';
import '../core/gift_tracking.dart';
import '../core/gift_workspace.dart';
import '../core/providers/app_providers.dart';
import '../core/responsive_layout.dart';
import '../create_activity_dialog.dart';
import '../models/gift_activity.dart';
import '../models/group_practice_instance.dart';
import '../widgets/gifts_workspace_tiles.dart';
import '../widgets/member_service_projects_section.dart';
import 'activity_detail_screen.dart';
import 'gift_done_detail_screen.dart';
import 'group_practice_detail_screen.dart';
import 'service_hour_done_detail_screen.dart';

class SharingMyGiftsScreen extends ConsumerStatefulWidget {
  const SharingMyGiftsScreen({super.key});

  @override
  ConsumerState<SharingMyGiftsScreen> createState() =>
      _SharingMyGiftsScreenState();
}

class _SharingMyGiftsScreenState extends ConsumerState<SharingMyGiftsScreen>
    with TickerProviderStateMixin {
  GiftFilterKind _filterKind = GiftFilterKind.all;
  String? _filterOrgId;
  String? _filterGroupId;
  GiftDoneRange _doneRange = GiftDoneRange.thisWeek;
  GiftScheduleFilter _scheduleFilter = GiftScheduleFilter.dueToday;
  late final TabController _tabController;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  void _openGift(GiftActivity gift) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(
          activity: gift,
          onUpdate: (updated) {
            ref.read(giftServiceProvider).saveGift(updated);
          },
        ),
      ),
    );
  }

  void _openPractice(GroupPracticeInstance practice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupPracticeDetailScreen(practice: practice),
      ),
    );
  }

  void _openDoneRow(GiftDoneRow row) {
    if (row.gift != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GiftDoneDetailScreen(
            gift: row.gift!,
            completedOn: row.completedOn,
          ),
        ),
      );
      return;
    }
    if (row.practice != null) {
      _openPractice(row.practice!);
      return;
    }
    if (row.hours != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceHourDoneDetailScreen(entry: row.hours!),
        ),
      );
    }
  }

  void _openDueToday() {
    setState(() => _scheduleFilter = GiftScheduleFilter.dueToday);
    _tabController.animateTo(0);
  }

  void _openCompletedToday() {
    setState(() => _doneRange = GiftDoneRange.today);
    _tabController.animateTo(3);
  }

  @override
  Widget build(BuildContext context) {
    final giftsAsync = ref.watch(userGiftsStreamProvider);
    final practicesAsync = ref.watch(userGroupPracticesStreamProvider);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Gifts could not be loaded yet. Sign-in sometimes '
                  'finishes a moment after the first request.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(userGiftsStreamProvider),
                  child: const Text('Try again'),
                ),
              ],
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
                fabClearance: fabClearance,
                compact: compact,
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
    required double fabClearance,
    required bool compact,
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
    final hours =
        ref.watch(memberHourEntriesProvider).valueOrNull ?? const <ServiceHourEntry>[];
    final scopedHours = hours.where((entry) {
      switch (_filterKind) {
        case GiftFilterKind.all:
          return true;
        case GiftFilterKind.personal:
          return false;
        case GiftFilterKind.organization:
          return _filterOrgId != null && entry.orgId == _filterOrgId;
        case GiftFilterKind.group:
          return true;
      }
    }).toList();
    final assignedProjects =
        ref.watch(memberAssignedServiceProjectsProvider).valueOrNull ?? const [];
    final projectTitles = {
      for (final project in assignedProjects) project.id: project.title,
    };

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

    final scheduleGifts = GiftWorkspace.scheduleGifts(
      activities,
      DateTime.now(),
      _scheduleFilter,
    );
    final schedulePractices = GiftWorkspace.schedulePractices(
      groupPractices,
      DateTime.now(),
      _scheduleFilter,
    );
    final activeGifts = GiftWorkspace.activeChallenges(activities);
    final completedToday = GiftWorkspace.completedTodayRows(
      gifts: activities,
      practices: groupPractices,
      hours: scopedHours,
      now: DateTime.now(),
    );
    final dueTodayCount = GiftWorkspace.dueTodayCount(
      gifts: activities,
      practices: groupPractices,
    );
    final doneRows = GiftWorkspace.doneRows(
      gifts: activities,
      practices: groupPractices,
      hours: scopedHours,
      range: _doneRange,
    );

    final filterBar = _GiftsFilterBar(
      kind: _filterKind,
      organizationId: _filterOrgId,
      groupId: _filterGroupId,
      organizations: [
        for (final org in orgs) (id: org.id, name: org.name),
      ],
      groups: [
        for (final g in groups) (id: g.groupId, name: g.userFacingLabel),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: filterBar,
        ),
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            isScrollable: compact,
            tabAlignment: compact ? TabAlignment.start : TabAlignment.fill,
            labelColor: AppColors.primaryMaroon,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.gold,
            tabs: const [
              Tab(text: 'Schedule'),
              Tab(text: 'Service'),
              Tab(text: 'Active'),
              Tab(text: 'Done'),
            ],
          ),
        ),
        GiftsDueCompletedStatusLine(
          dueTodayCount: dueTodayCount,
          completedTodayCount: completedToday.length,
          onDueTodayTap: _openDueToday,
          onCompletedTodayTap: _openCompletedToday,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ScheduleTab(
                gifts: scheduleGifts,
                practices: schedulePractices,
                filter: _scheduleFilter,
                orgLogos: orgLogos,
                userPhotoUrl: userPhotoUrl,
                photoCacheBustMs: photoCacheBustMs,
                fabClearance: fabClearance,
                onFilterChanged: (filter) =>
                    setState(() => _scheduleFilter = filter),
                onCompleteGift: _completeGift,
                onCompletePractice: _completeGroupPractice,
                onOpenGift: _openGift,
                onOpenPractice: _openPractice,
              ),
              _ServiceTab(
                filterKind: _filterKind,
                filterOrgId: _filterOrgId,
                filterGroupId: _filterGroupId,
                fabClearance: fabClearance,
              ),
              _ActiveTab(
                gifts: activeGifts,
                orgLogos: orgLogos,
                userPhotoUrl: userPhotoUrl,
                photoCacheBustMs: photoCacheBustMs,
                fabClearance: fabClearance,
                onCompleteGift: _completeGift,
                onOpenGift: _openGift,
              ),
              _DoneTab(
                rows: doneRows,
                range: _doneRange,
                projectTitles: projectTitles,
                fabClearance: fabClearance,
                onRangeChanged: (range) => setState(() => _doneRange = range),
                onOpenRow: _openDoneRow,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({
    required this.gifts,
    required this.practices,
    required this.filter,
    required this.orgLogos,
    required this.userPhotoUrl,
    required this.photoCacheBustMs,
    required this.fabClearance,
    required this.onFilterChanged,
    required this.onCompleteGift,
    required this.onCompletePractice,
    required this.onOpenGift,
    required this.onOpenPractice,
  });

  final List<GiftActivity> gifts;
  final List<GroupPracticeInstance> practices;
  final GiftScheduleFilter filter;
  final Map<String, String?> orgLogos;
  final String? userPhotoUrl;
  final int? photoCacheBustMs;
  final double fabClearance;
  final ValueChanged<GiftScheduleFilter> onFilterChanged;
  final ValueChanged<GiftActivity> onCompleteGift;
  final ValueChanged<GroupPracticeInstance> onCompletePractice;
  final ValueChanged<GiftActivity> onOpenGift;
  final ValueChanged<GroupPracticeInstance> onOpenPractice;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, fabClearance),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in GiftScheduleFilter.values)
              ChoiceChip(
                label: Text(_filterLabel(option)),
                selected: filter == option,
                onSelected: (_) => onFilterChanged(option),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (gifts.isEmpty && practices.isEmpty)
          Text(
            _emptyMessage(filter),
            style: const TextStyle(color: AppColors.textSecondary),
          )
        else ...[
          for (final practice in practices)
            GiftsPracticeWorkTile(
              practice: practice,
              brandLogoUrl: orgLogos[practice.organizationId],
              onComplete: () => onCompletePractice(practice),
              onOpen: () => onOpenPractice(practice),
            ),
          for (final gift in gifts)
            GiftsWorkTile(
              gift: gift,
              brandLogoUrl: Organization.resolveLogoUrl(
                organizationLogoUrl: gift.organizationId == null
                    ? null
                    : orgLogos[gift.organizationId],
                fallback: gift.groupLogoUrl,
              ),
              userPhotoUrl: userPhotoUrl,
              photoCacheBustMs: photoCacheBustMs,
              onComplete: () => onCompleteGift(gift),
              onOpen: () => onOpenGift(gift),
            ),
        ],
      ],
    );
  }

  static String _filterLabel(GiftScheduleFilter filter) {
    switch (filter) {
      case GiftScheduleFilter.dueToday:
        return 'Due today';
      case GiftScheduleFilter.thisWeek:
        return 'This week';
      case GiftScheduleFilter.allScheduled:
        return 'All scheduled';
    }
  }

  static String _emptyMessage(GiftScheduleFilter filter) {
    switch (filter) {
      case GiftScheduleFilter.dueToday:
        return 'Nothing due today. Open This week or All scheduled for later Gifts.';
      case GiftScheduleFilter.thisWeek:
        return 'Nothing scheduled this week in this filter.';
      case GiftScheduleFilter.allScheduled:
        return 'No recurring Gifts or reminders in this filter. '
            'One-time items without a reminder live on Active.';
    }
  }
}

class _ServiceTab extends StatelessWidget {
  const _ServiceTab({
    required this.filterKind,
    required this.filterOrgId,
    required this.filterGroupId,
    required this.fabClearance,
  });

  final GiftFilterKind filterKind;
  final String? filterOrgId;
  final String? filterGroupId;
  final double fabClearance;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, fabClearance),
      children: [
        if (filterKind == GiftFilterKind.personal)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Service projects belong to organizations and groups. '
              'Choose All, By Organization, or By Group to see assignments.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          MemberServiceProjectsSection(
            filterKind: filterKind,
            filterOrgId: filterOrgId,
            filterGroupId: filterGroupId,
            showHeader: false,
          ),
      ],
    );
  }
}

class _ActiveTab extends StatelessWidget {
  const _ActiveTab({
    required this.gifts,
    required this.orgLogos,
    required this.userPhotoUrl,
    required this.photoCacheBustMs,
    required this.fabClearance,
    required this.onCompleteGift,
    required this.onOpenGift,
  });

  final List<GiftActivity> gifts;
  final Map<String, String?> orgLogos;
  final String? userPhotoUrl;
  final int? photoCacheBustMs;
  final double fabClearance;
  final ValueChanged<GiftActivity> onCompleteGift;
  final ValueChanged<GiftActivity> onOpenGift;

  @override
  Widget build(BuildContext context) {
    if (gifts.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, fabClearance),
        children: const [
          Text(
            'No open items without a cadence or reminder. Recurring Gifts stay on Schedule.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, fabClearance),
      children: [
        for (final gift in gifts)
          GiftsWorkTile(
            gift: gift,
            brandLogoUrl: Organization.resolveLogoUrl(
              organizationLogoUrl: gift.organizationId == null
                  ? null
                  : orgLogos[gift.organizationId],
              fallback: gift.groupLogoUrl,
            ),
            userPhotoUrl: userPhotoUrl,
            photoCacheBustMs: photoCacheBustMs,
            onComplete: () => onCompleteGift(gift),
            onOpen: () => onOpenGift(gift),
          ),
      ],
    );
  }
}

class _DoneTab extends StatelessWidget {
  const _DoneTab({
    required this.rows,
    required this.range,
    required this.projectTitles,
    required this.fabClearance,
    required this.onRangeChanged,
    required this.onOpenRow,
  });

  final List<GiftDoneRow> rows;
  final GiftDoneRange range;
  final Map<String, String> projectTitles;
  final double fabClearance;
  final ValueChanged<GiftDoneRange> onRangeChanged;
  final ValueChanged<GiftDoneRow> onOpenRow;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, fabClearance),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in GiftDoneRange.values)
              ChoiceChip(
                label: Text(_rangeLabel(option)),
                selected: range == option,
                onSelected: (_) => onRangeChanged(option),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text(
            'No completed Gifts or counted service hours in this range.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          for (final row in rows)
            GiftsDoneTile(
              row: row,
              projectTitle: row.hours == null
                  ? null
                  : projectTitles[row.hours!.projectId],
              onOpen: () => onOpenRow(row),
            ),
      ],
    );
  }

  static String _rangeLabel(GiftDoneRange range) {
    switch (range) {
      case GiftDoneRange.today:
        return 'Today';
      case GiftDoneRange.thisWeek:
        return 'This week';
      case GiftDoneRange.thisSemester:
        return 'This semester';
      case GiftDoneRange.all:
        return 'All';
    }
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
                onSelected: (_) => onKindChanged(GiftFilterKind.organization),
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
