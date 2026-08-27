// lib/screens/activity_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../core/gift_tracking.dart';
import '../core/gift_reminder_utils.dart';
import '../core/catholic_prayers/prayer_gift_link.dart';
import '../core/providers/app_providers.dart';
import '../core/providers/reflection_providers.dart';
import '../core/user_text_input.dart';
import '../models/gift_activity.dart';
import '../models/gift_status.dart';
import '../widgets/gift_share_dialog.dart';
import '../widgets/gift_reminder_section.dart';
import '../widgets/gift_prayer_link_tile.dart';
import '../widgets/group_brand_mark.dart';
import '../widgets/linked_markdown_body.dart';
import '../widgets/profile_avatar.dart';
import '../admin/models/organization.dart';
import '../admin/providers/admin_providers.dart';
import '../widgets/prayer_link_picker.dart';

class ActivityDetailScreen extends ConsumerStatefulWidget {
  final GiftActivity activity;
  final Function(GiftActivity) onUpdate;

  const ActivityDetailScreen({
    super.key,
    required this.activity,
    required this.onUpdate,
  });

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  late GiftActivity _activity;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _loadingReflection = true;
  bool _syncingReflection = false;
  bool _savingDetails = false;
  String? _linkedPrayerId;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _titleController.text = _activity.title;
    _descriptionController.text = _activity.description;
    _noteController.text = _activity.note ?? '';
    _linkedPrayerId = _activity.linkedPrayerId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReflectionNote());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _applyActivityUpdate(GiftActivity updated) {
    setState(() {
      _activity = updated;
      if (_titleController.text.trim() != updated.title) {
        _titleController.text = updated.title;
      }
      if (_descriptionController.text.trim() != updated.description) {
        _descriptionController.text = updated.description;
      }
      _linkedPrayerId = updated.linkedPrayerId;
    });
    widget.onUpdate(updated);
  }

  Future<void> _saveActivityDetails() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an activity title')),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter action steps')),
      );
      return;
    }

    setState(() => _savingDetails = true);
    try {
      final updated = _activity.copyWith(
        title: title,
        description: description,
        linkedPrayerId: _linkedPrayerId,
      );
      await ref.read(giftServiceProvider).saveGift(updated);
      if (!mounted) return;

      if (title != _activity.title) {
        try {
          await _ensureAuthForReflection();
          await ref.read(reflectionServiceProvider).upsertGiftReflection(
                giftId: _activity.id,
                giftTitle: title,
                body: _noteController.text.trim(),
              );
        } catch (_) {
          // Reflection title sync is best-effort.
        }
      }

      _applyActivityUpdate(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity updated')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save activity: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingDetails = false);
    }
  }

  Future<void> _completeForToday() async {
    final giftService = ref.read(giftServiceProvider);
    try {
      final updated = await giftService.completeGiftForToday(_activity);
      if (!mounted) return;

      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Already ${GiftTracking.completedStatusLabel(_activity).toLowerCase()}',
            ),
          ),
        );
        return;
      }

      _applyActivityUpdate(updated);

      final streakLine = updated.currentStreak > 1
          ? ' · ${updated.currentStreak}-day streak!'
          : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${GiftTracking.completedStatusLabel(updated)}$streakLine'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  Future<void> _ensureAuthForReflection() async {
    if (ref.read(authServiceProvider).currentUser != null) return;
    await ref.read(authCoordinatorProvider).continueAsGuest();
  }

  Future<void> _loadReflectionNote() async {
    try {
      await _ensureAuthForReflection();
      final reflectionService = ref.read(reflectionServiceProvider);
      final thread = await reflectionService.findThreadForGift(_activity.id);
      if (thread != null) {
        final body = await reflectionService.latestEntryBodyForThread(thread.id);
        if (body != null && body.trim().isNotEmpty && mounted) {
          setState(() {
            _noteController.text = body;
          });
        }
      } else if (_activity.note?.trim().isNotEmpty == true) {
        await ref.read(reflectionServiceProvider).upsertGiftReflection(
              giftId: _activity.id,
              giftTitle: _activity.title,
              body: _activity.note!,
            );
      }
    } catch (_) {
      // Keep gift note field usable even if reflection sync fails.
    } finally {
      if (mounted) setState(() => _loadingReflection = false);
    }
  }

  Future<void> _saveNote() async {
    final text = _noteController.text;
    final updated = _activity.copyWith(
      note: text.trim().isEmpty ? null : text.trim(),
    );
    _applyActivityUpdate(updated);

    if (text.trim().isEmpty || _syncingReflection) return;

    setState(() => _syncingReflection = true);
    try {
      await _ensureAuthForReflection();
      await ref.read(reflectionServiceProvider).upsertGiftReflection(
            giftId: _activity.id,
            giftTitle: _activity.title,
            body: text,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save to My Reflections: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingReflection = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doneInPeriod = GiftTracking.isCompletedInPeriod(_activity);
    final isDue = GiftTracking.isDue(_activity);
    final isOneTime = GiftTracking.isOneTime(_activity);
    final isFinished = _activity.status == GiftStatus.completed;
    final completeLabel = GiftTracking.completeActionLabel(_activity);
    final completedLabel = GiftTracking.completedStatusLabel(_activity);
    final linkedPrayerId = PrayerGiftLink.resolvePrayerId(_activity);
    final orgs =
        ref.watch(memberOrganizationsProvider).valueOrNull ?? const [];
    String? orgLogo;
    final orgId = _activity.organizationId;
    if (orgId != null && orgId.isNotEmpty) {
      for (final org in orgs) {
        if (org.id == orgId) {
          orgLogo = org.resolvedLogoUrl;
          break;
        }
      }
    }
    final brandLogoUrl = Organization.resolveLogoUrl(
      organizationLogoUrl: orgLogo,
      fallback: _activity.groupLogoUrl,
    );
    final profile = ref.watch(userProfileStreamProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Detail'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_activity.isGroupGift) ...[
              Row(
                children: [
                  GroupBrandMark(
                    groupName: _activity.brandLabel,
                    logoUrl: brandLogoUrl,
                    orgId: orgId,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Shared by ${_activity.brandLabel}. The group definition '
                      'cannot be edited here.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    ProfileAvatar(
                      photoUrl: profile?.photoUrl,
                      radius: 24,
                      cacheBustMs: profile?.updatedAt?.millisecondsSinceEpoch,
                      loadFromStorageWhenEmpty: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your Sharing My Gifts activity',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Text(
              'Activity',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_activity.definitionLocked) ...[
              Text(
                _activity.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(_activity.description),
            ] else ...[
              UserTextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              UserTextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Action steps',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              PrayerLinkPicker(
                selectedPrayerId: _linkedPrayerId,
                enabled: !_savingDetails,
                onChanged: (id) => setState(() => _linkedPrayerId = id),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _savingDetails ? null : _saveActivityDetails,
                  icon: _savingDetails
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save activity'),
                ),
              ),
            ],
            if (linkedPrayerId != null) ...[
              const SizedBox(height: 16),
              GiftPrayerLinkTile(prayerId: linkedPrayerId),
            ],
            const SizedBox(height: 8),
            Text(
              [
                _activity.frequency,
                if (_activity.hasReminder)
                  GiftReminderUtils.recurrenceSummary(_activity)
                else if (_activity.specificTime != null)
                  'at ${GiftReminderUtils.formatDisplayTime(_activity.specificTime)}',
              ].join(' · '),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (_activity.totalCompletions > 0 || _activity.currentStreak > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_activity.totalCompletions > 0)
                      Chip(
                        avatar: const Icon(Icons.check, size: 16),
                        label: Text('${_activity.totalCompletions} total'),
                      ),
                    if (_activity.currentStreak > 0)
                      Chip(
                        avatar: const Icon(
                          Icons.local_fire_department,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        label: Text('${_activity.currentStreak}-day streak'),
                      ),
                  ],
                ),
              ),
            const Divider(height: 40),
            if (_activity.isActive && (isDue || isOneTime) && !isFinished)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: doneInPeriod ? null : _completeForToday,
                    icon: Icon(doneInPeriod ? Icons.check_circle : Icons.check),
                    label: Text(
                      doneInPeriod ? completedLabel : completeLabel,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'My Reflection',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Saved privately to My Reflections and linked to this activity.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            if (_loadingReflection)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              )
            else
              UserTextField(
                controller: _noteController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Write your private reflection on this activity',
                  border: const OutlineInputBorder(),
                  suffixIcon: _syncingReflection
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: (_) => _saveNote(),
              ),
            const SizedBox(height: 32),
            GiftReminderSection(
              gift: _activity,
              onUpdated: _applyActivityUpdate,
            ),
            const SizedBox(height: 32),
            if (_activity.hasOriginalGuidance)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Original Guidance',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The WWJD conversation that inspired this activity.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('View Original Guidance'),
                    onPressed: () {
                      final question = _activity.linkedQuestionText?.trim();
                      final response = _activity.linkedResponseText?.trim();

                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Original Guidance'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (question != null && question.isNotEmpty) ...[
                                  const Text(
                                    'Your question',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(question),
                                  const SizedBox(height: 16),
                                ],
                                if (response != null && response.isNotEmpty) ...[
                                  const Text(
                                    'WWJD response',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  LinkedMarkdownBody(data: response),
                                ],
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share Gift'),
                  onPressed: () {
                    GiftShareDialog.show(
                      context,
                      title: _activity.title,
                      description: _activity.description,
                      linkedActivityId: _activity.id,
                      linkedPrayerId: linkedPrayerId,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
