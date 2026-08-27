import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../core/gift_calendar_export.dart';
import '../core/gift_ics.dart';
import '../core/gift_reminder_utils.dart';
import '../core/gift_title_time.dart';
import '../core/mobile_touch.dart';
import '../core/providers/app_providers.dart';
import '../core/services/gift_reminder_service.dart';
import '../models/gift_activity.dart';

/// Reminder settings and Add to Calendar for a Kingdom Challenge gift.
class GiftReminderSection extends ConsumerStatefulWidget {
  const GiftReminderSection({
    super.key,
    required this.gift,
    required this.onUpdated,
  });

  final GiftActivity gift;
  final ValueChanged<GiftActivity> onUpdated;

  @override
  ConsumerState<GiftReminderSection> createState() =>
      _GiftReminderSectionState();
}

class _GiftReminderSectionState extends ConsumerState<GiftReminderSection> {
  late bool _hasReminder;
  late TimeOfDay _time;
  late String _frequency;
  late Set<String> _daysOfWeek;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _syncFromGift(widget.gift);
  }

  @override
  void didUpdateWidget(covariant GiftReminderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gift.id != widget.gift.id ||
        oldWidget.gift.updatedAt != widget.gift.updatedAt) {
      _syncFromGift(widget.gift);
    }
  }

  void _syncFromGift(GiftActivity gift) {
    _hasReminder = gift.hasReminder;
    _time = GiftReminderUtils.parseTime(gift.specificTime);
    _frequency = gift.frequency;
    _daysOfWeek = gift.daysOfWeek.toSet();
  }

  GiftActivity _draftGift() {
    return widget.gift.copyWith(
      hasReminder: _hasReminder,
      specificTime: GiftReminderUtils.formatStoredTime(_time),
      frequency: _frequency,
      daysOfWeek: _daysOfWeek.toList()..sort(_weekdaySort),
    );
  }

  int _weekdaySort(String a, String b) {
    return GiftReminderUtils.weekdayNames
        .indexOf(a)
        .compareTo(GiftReminderUtils.weekdayNames.indexOf(b));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Reminder time',
      confirmText: 'Set',
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _saveReminder() async {
    setState(() => _busy = true);
    try {
      var updated = _draftGift();
      if (GiftTitleTime.titleReflectsTime(updated.title)) {
        updated = updated.copyWith(
          title: GiftTitleTime.syncTitleWithTime(
            title: updated.title,
            previousStoredTime: widget.gift.specificTime,
            newTime: _time,
          ),
        );
      }
      await ref.read(giftServiceProvider).saveGift(updated);
      widget.onUpdated(updated);

      if (_hasReminder && !kIsWeb) {
        await GiftReminderService.instance.requestPermissions();
        await GiftReminderService.instance.schedule(updated);
      } else if (!_hasReminder && !kIsWeb) {
        await GiftReminderService.instance.cancel(updated);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _hasReminder
                ? 'Reminder saved — ${GiftReminderUtils.recurrenceSummary(updated)}'
                : 'Reminder turned off',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save reminder: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addToCalendar() async {
    setState(() => _busy = true);
    try {
      final draft = _draftGift();
      final ics = GiftIcs.build(draft);
      final filename = GiftIcs.filenameFor(draft);
      await exportGiftCalendarFile(filename: filename, icsContent: ics);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Calendar file downloaded — open it to add this gift to your calendar.'
                : 'Choose your calendar app to add this Kingdom Challenge.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create calendar file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draftGift();
    final summary = GiftReminderUtils.recurrenceSummary(draft);

    return Card(
      color: AppColors.parchmentDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_outlined,
                    color: AppColors.primaryMaroon, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Reminders & Calendar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Set a gentle nudge for this Kingdom Challenge, or add it to your calendar.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me'),
              subtitle: _hasReminder ? Text(summary) : null,
              value: _hasReminder,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _hasReminder = value),
            ),
            if (_hasReminder) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Time of day'),
                subtitle: Text(GiftReminderUtils.formatDisplayTime(
                  GiftReminderUtils.formatStoredTime(_time),
                )),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _pickTime,
              ),
              MobileFriendlyDropdown(
                label: 'Recurrence',
                value: _frequency,
                items: const ['Daily', 'Weekly', 'Monthly', 'One-time'],
                enabled: !_busy,
                onChanged: (value) {
                  setState(() {
                    _frequency = value;
                    if (value != 'Weekly') _daysOfWeek.clear();
                  });
                },
              ),
              if (_frequency == 'Weekly') ...[
                const SizedBox(height: 8),
                const Text(
                  'Days (optional — leave empty for any day)',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final day in GiftReminderUtils.weekdayNames)
                      FilterChip(
                        label: Text(day.substring(0, 3)),
                        selected: _daysOfWeek.contains(day),
                        onSelected: _busy
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected) {
                                    _daysOfWeek.add(day);
                                  } else {
                                    _daysOfWeek.remove(day);
                                  }
                                });
                              },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                summary,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primaryMaroon.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (kIsWeb && _hasReminder)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'On the web, calendar export is the most reliable reminder. '
                  'Each calendar entry includes a link back to this activity in WWJD-DI '
                  'so you can mark it complete and capture your reflection.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              )
            else if (kIsWeb)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Calendar entries include a link back to this activity in WWJD-DI.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _saveReminder,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save Reminder'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _addToCalendar,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Add to Calendar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
