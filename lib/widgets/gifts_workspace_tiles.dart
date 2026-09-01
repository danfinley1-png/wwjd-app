import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../admin/models/service_hours.dart';
import '../core/app_colors.dart';
import '../core/gift_reminder_utils.dart';
import '../core/gift_tracking.dart';
import '../core/gift_workspace.dart';
import '../core/group_practice_tracking.dart';
import '../core/mobile_touch.dart';
import '../models/gift_activity.dart';
import '../models/group_practice_instance.dart';
import 'group_brand_mark.dart';
import 'profile_avatar.dart';

class GiftsDueCompletedStatusLine extends StatelessWidget {
  const GiftsDueCompletedStatusLine({
    super.key,
    required this.dueTodayCount,
    required this.completedTodayCount,
    required this.onDueTodayTap,
    required this.onCompletedTodayTap,
  });

  final int dueTodayCount;
  final int completedTodayCount;
  final VoidCallback onDueTodayTap;
  final VoidCallback onCompletedTodayTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Flexible(
            child: _StatusLink(
              label: 'Due today: $dueTodayCount',
              onTap: onDueTodayTap,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('·', style: TextStyle(color: AppColors.textSecondary)),
          ),
          Flexible(
            child: _StatusLink(
              label: 'Completed today: $completedTodayCount',
              onTap: onCompletedTodayTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLink extends StatelessWidget {
  const _StatusLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryMaroon,
          ),
        ),
      ),
    );
  }
}

class GiftsWorkTile extends StatelessWidget {
  const GiftsWorkTile({
    super.key,
    required this.gift,
    required this.onComplete,
    required this.onOpen,
    this.brandLogoUrl,
    this.userPhotoUrl,
    this.photoCacheBustMs,
    this.dense = false,
  });

  final GiftActivity gift;
  final VoidCallback onComplete;
  final VoidCallback onOpen;
  final String? brandLogoUrl;
  final String? userPhotoUrl;
  final int? photoCacheBustMs;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final dueLabel = GiftTracking.dueStatusLabel(gift);
    final meta = [
      if (gift.isGroupGift) gift.brandLabel,
      gift.frequency,
      if (dueLabel.isNotEmpty) dueLabel,
      if (gift.hasReminder && gift.specificTime != null)
        GiftReminderUtils.formatDisplayTime(gift.specificTime),
    ].join(' · ');

    return Card(
      margin: EdgeInsets.only(bottom: dense ? 4 : 8),
      child: ListTile(
        dense: dense,
        visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: gift.isGroupGift
            ? GroupBrandMark(
                groupName: gift.brandLabel,
                logoUrl: brandLogoUrl ?? gift.groupLogoUrl,
                orgId: gift.organizationId,
                size: dense ? 32 : 40,
              )
            : ProfileAvatar(
                photoUrl: userPhotoUrl,
                radius: dense ? 16 : 20,
                cacheBustMs: photoCacheBustMs,
                loadFromStorageWhenEmpty: true,
              ),
        title: Text(
          gift.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: meta.isEmpty
            ? null
            : Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: GiftTracking.completeActionLabel(gift),
              onPressed: onComplete,
              icon: const Icon(Icons.check_circle_outline),
              style: mobileIconButtonStyle(context),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

class GiftsPracticeWorkTile extends StatelessWidget {
  const GiftsPracticeWorkTile({
    super.key,
    required this.practice,
    required this.onComplete,
    required this.onOpen,
    this.brandLogoUrl,
    this.dense = false,
  });

  final GroupPracticeInstance practice;
  final VoidCallback onComplete;
  final VoidCallback onOpen;
  final String? brandLogoUrl;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final summary = GroupPracticeTracking.timesSummary(practice);
    final dueNow = GiftWorkspace.practiceDueToday(practice);
    final nextSlot = GroupPracticeTracking.nextDueSlotLabel(practice);
    final meta = [
      if (practice.groupName != null) practice.groupName!,
      summary,
      if (dueNow) nextSlot,
    ].join(' · ');

    return Card(
      margin: EdgeInsets.only(bottom: dense ? 4 : 8),
      child: ListTile(
        dense: dense,
        visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: GroupBrandMark(
          groupName: practice.groupName ?? practice.title,
          logoUrl: brandLogoUrl,
          orgId: practice.organizationId,
          size: dense ? 32 : 40,
        ),
        title: Text(
          practice.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dueNow)
              IconButton(
                tooltip: 'Complete',
                onPressed: onComplete,
                icon: const Icon(Icons.check_circle_outline),
                style: mobileIconButtonStyle(context),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

class GiftsDoneTile extends StatelessWidget {
  const GiftsDoneTile({
    super.key,
    required this.row,
    required this.onOpen,
    this.projectTitle,
  });

  final GiftDoneRow row;
  final VoidCallback onOpen;
  final String? projectTitle;

  static final _dateFormat = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    final title = row.hours != null ? (projectTitle ?? row.title) : row.title;
    final subtitle = [
      if (row.hours != null)
        '${ServiceHourEntry.formatHours(row.hours!.hours)} · ${row.hours!.statusDisplayLabel}',
      if (row.gift != null) row.gift!.frequency,
      if (row.practice != null) 'Group practice',
      _dateFormat.format(row.completedOn),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          row.hours != null
              ? Icons.volunteer_activism_outlined
              : row.practice != null
                  ? Icons.groups_outlined
                  : Icons.card_giftcard_outlined,
          color: AppColors.primaryMaroon,
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpen,
      ),
    );
  }
}
