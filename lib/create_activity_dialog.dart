import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uuid/uuid.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/gift_activity.dart';

import '../core/providers/app_providers.dart';
import '../core/content_guidance/content_guidance_models.dart';
import '../core/content_guidance/shared_content_gate.dart';
import '../core/gift_reminder_utils.dart';
import '../core/gift_share_payload.dart';
import '../core/catholic_prayers/prayer_gift_link.dart';
import '../core/mobile_touch.dart';
import '../core/models/shareable_group.dart';
import '../core/responsive_layout.dart';
import '../core/services/gift_reminder_service.dart';
import '../core/user_text_input.dart';
import '../widgets/prayer_link_picker.dart';


class CreateActivityDialog extends ConsumerStatefulWidget {

  final VoidCallback? onActivityCreated;



  const CreateActivityDialog({super.key, this.onActivityCreated});



  @override

  ConsumerState<CreateActivityDialog> createState() => _CreateActivityDialogState();

}



class _CreateActivityDialogState extends ConsumerState<CreateActivityDialog> {

  final _titleController = TextEditingController();

  final _descriptionController = TextEditingController();



  String _frequency = 'Daily';

  bool _hasReminder = true;

  TimeOfDay _time = GiftReminderUtils.defaultTime;

  String _shareDestination = 'none';

  String? _selectedGroupId;

  String? _linkedPrayerId;

  bool _isSaving = false;



  final List<String> _frequencies = ['Daily', 'Weekly', 'Monthly', 'One-time'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userGroupsServiceProvider).repairShareableGroupsIndex().catchError((_) {});
    });
  }

  @override

  void dispose() {

    _titleController.dispose();

    _descriptionController.dispose();

    super.dispose();

  }



  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Activity time',
      confirmText: 'Set',
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _createActivity() async {

    final String title = _titleController.text.trim();

    if (title.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Please enter a title')),

      );

      return;

    }



    setState(() => _isSaving = true);



    String? communityShareMessage;



    try {

      final String description = _descriptionController.text.trim().isNotEmpty

          ? _descriptionController.text.trim()

          : "Regular practice of this gift to grow in faith and service.";



      final activity = GiftActivity(

        id: const Uuid().v4(),

        title: title,

        description: description,

        linkedQuestionId: null,

        linkedPrayerId: _linkedPrayerId,

        frequency: _frequency,

        hasReminder: _hasReminder,

        specificTime: _hasReminder
            ? GiftReminderUtils.formatStoredTime(_time)
            : null,

        isCompleted: false,

        userId: FirebaseAuth.instance.currentUser?.uid,

        createdAt: DateTime.now(),

      );



      final giftService = ref.read(giftServiceProvider);

      if (giftService.findDuplicate(activity, await giftService.getUserGifts()) != null) {

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(content: Text('This activity is already in your plan')),

          );

        }

        setState(() => _isSaving = false);

        return;

      }



      await giftService.saveGift(activity);

      if (_hasReminder && !kIsWeb) {
        await GiftReminderService.instance.requestPermissions();
        await GiftReminderService.instance.schedule(activity);
      }

      if (_shareDestination == 'group') {
        final groups =
            ref.read(shareableGroupsProvider).valueOrNull ?? const [];
        ShareableGroup? group;
        for (final g in groups) {
          if (g.groupId == _selectedGroupId) {
            group = g;
            break;
          }
        }
        if (group == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Added to Sharing My Gifts. Group share skipped — '
                  'choose a group you belong to.',
                ),
              ),
            );
          }
        } else {
          if (FirebaseAuth.instance.currentUser == null) {
            await ref.read(authCoordinatorProvider).continueAsGuest();
          }
          if (!mounted) {
            setState(() => _isSaving = false);
            return;
          }
          final gateResult = await sharedContentGate.prepare(
            context,
            input: SharedContentInput(
              title: 'Sharing My Gifts: ${activity.title}',
              question: activity.shareQuestion,
              description: activity.description,
            ),
            channel: SharedContentChannel.groupShare,
          );
          if (gateResult != null) {
            final prepared = gateResult.input;
            await ref.read(groupShareServiceProvider).shareGift(
                  group: group,
                  payload: GiftSharePayload(
                    title: prepared.title ?? activity.title,
                    description: prepared.description ?? activity.description,
                    personalNote: prepared.personalNote ?? '',
                    shareAnonymously: true,
                    linkedActivityId: activity.id,
                    linkedPrayerId: PrayerGiftLink.resolvePrayerId(activity),
                  ),
                );
            if (mounted) {
              communityShareMessage =
                  'Added & shared to ${group.userFacingLabel}: $title';
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Added to Sharing My Gifts. Group share was cancelled.',
                ),
              ),
            );
          }
        }
      } else if (_shareDestination == 'community') {

        if (FirebaseAuth.instance.currentUser == null) {

          await ref.read(authCoordinatorProvider).continueAsGuest();

        }

        if (!mounted) {
          setState(() => _isSaving = false);
          return;
        }

        final gateResult = await sharedContentGate.prepare(
          context,
          input: SharedContentInput(
            title: 'Sharing My Gifts: ${activity.title}',
            question: 'Activity: ${activity.title}',
            description: activity.description,
          ),
          channel: SharedContentChannel.giftCommunity,
        );

        if (gateResult == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Added to Sharing My Gifts. Community share was cancelled.',
                ),
              ),
            );
          }
        } else {
          final prepared = gateResult.input;
          final added = await ref.read(walkTogetherServiceProvider).addJourney(
                title: prepared.title ?? 'Sharing My Gifts: ${activity.title}',
                question: prepared.question ?? 'Activity: ${activity.title}',
                response: prepared.description ?? activity.description,
                shareType: 'community',
                linkedActivityId: activity.id,
                shareAnonymously: true,
              );

          if (mounted) {

            communityShareMessage = added

                ? 'Added & shared to Walk Together: $title'

                : 'Added to Sharing My Gifts. Already on Walk Together: $title';

          }
        }

      }



      widget.onActivityCreated?.call();



      if (mounted) {

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(
              switch (_shareDestination) {
                'community' => communityShareMessage ??
                    'Added & shared to Walk Together: $title',
                'group' => communityShareMessage ??
                    'Added to Sharing My Gifts: $title',
                _ => 'Added to Sharing My Gifts: $title',
              },
            ),

          ),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Error saving activity: $e'), backgroundColor: Colors.red),

        );

      }

    } finally {

      if (mounted) setState(() => _isSaving = false);

    }

  }



  @override

  Widget build(BuildContext context) {

    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    final shareableGroupsAsync = ref.watch(shareableGroupsProvider);
    final shareableGroups =
        shareableGroupsAsync.valueOrNull ?? const [];
    final groupsLoading = shareableGroupsAsync.isLoading;
    final isSuperAdmin = ref.watch(isSuperAdminUserProvider).valueOrNull ?? false;



    return Dialog(

      backgroundColor: const Color(0xFFFFF8F0),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),

      child: keyboardAwarePadding(
        context: context,
        child: ConstrainedBox(

          constraints: BoxConstraints(

            maxWidth: responsiveDialogMaxWidth(context),

            maxHeight: maxHeight,

          ),

          child: SingleChildScrollView(

            padding: const EdgeInsets.all(20),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const Text(

                  'Create New Activity',

                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),

                ),

                const SizedBox(height: 8),

                const Text(

                  'Add to Sharing My Gifts Plan',

                  style: TextStyle(fontSize: 14, color: Colors.grey),

                ),

                const SizedBox(height: 24),

                UserTextField(

                  controller: _titleController,

                  decoration: const InputDecoration(

                    labelText: 'Activity Title',

                    hintText: 'e.g. Daily Gratitude Whisper',

                    border: OutlineInputBorder(),

                  ),

                  textCapitalization: TextCapitalization.sentences,

                ),

                const SizedBox(height: 16),

                UserTextField(

                  controller: _descriptionController,

                  maxLines: 3,

                  decoration: const InputDecoration(

                    labelText: 'Description',

                    hintText: 'Write a short reflection or action steps...',

                    border: OutlineInputBorder(),

                  ),

                  textCapitalization: TextCapitalization.sentences,

                ),

                const SizedBox(height: 16),

                PrayerLinkPicker(
                  selectedPrayerId: _linkedPrayerId,
                  enabled: !_isSaving,
                  onChanged: (id) => setState(() => _linkedPrayerId = id),
                ),

                const SizedBox(height: 16),

                MobileFriendlyDropdown(
                  label: 'Frequency',
                  value: _frequency,
                  items: _frequencies,
                  onChanged: (val) => setState(() => _frequency = val),
                ),

                const SizedBox(height: 12),

                SwitchListTile(

                  title: const Text('Enable Reminder'),

                  value: _hasReminder,

                  onChanged: (val) => setState(() => _hasReminder = val),

                  contentPadding: EdgeInsets.zero,

                ),

                if (_hasReminder)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: const Text('Time of day'),
                    subtitle: Text(
                      GiftReminderUtils.formatDisplayTime(
                        GiftReminderUtils.formatStoredTime(_time),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _isSaving ? null : _pickTime,
                  ),

                const SizedBox(height: 16),

                const Text(

                  'Share Activity',

                  style: TextStyle(fontWeight: FontWeight.bold),

                ),

                const SizedBox(height: 4),

                RadioListTile<String>(

                  title: const Text('Do not share'),

                  value: 'none',

                  groupValue: _shareDestination,

                  onChanged: (val) {

                    if (val != null) setState(() => _shareDestination = val);

                  },

                ),

                RadioListTile<String>(

                  title: const Text('Walk Together (Community)'),

                  value: 'community',

                  groupValue: _shareDestination,

                  onChanged: (val) {

                    if (val != null) setState(() => _shareDestination = val);

                  },

                ),

                RadioListTile<String>(

                  title: Text(
                    isSuperAdmin ? 'Share to a group' : 'Share to your group',
                  ),
                  subtitle: groupsLoading
                      ? const Text('Loading groups…')
                      : shareableGroups.isEmpty
                          ? Text(
                              isSuperAdmin
                                  ? 'No groups on the platform yet.'
                                  : 'Join a group in Admin → Organization → Groups, '
                                      'then return here.',
                            )
                          : null,

                  value: 'group',

                  groupValue: _shareDestination,

                  onChanged: groupsLoading || shareableGroups.isEmpty
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() {
                              _shareDestination = val;
                              _selectedGroupId ??= shareableGroups.first.groupId;
                            });
                          }
                        },

                ),

                if (_shareDestination == 'group' &&
                    shareableGroups.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  MobileFriendlyDropdown(
                    label: 'Choose group',
                    value: shareableGroups
                        .firstWhere(
                          (g) => g.groupId == _selectedGroupId,
                          orElse: () => shareableGroups.first,
                        )
                        .userFacingLabel,
                    items: shareableGroups
                        .map((g) => g.userFacingLabel)
                        .toList(),
                    onChanged: (label) {
                      final match = shareableGroups.where(
                        (g) => g.userFacingLabel == label,
                      );
                      if (match.isNotEmpty) {
                        setState(() => _selectedGroupId = match.first.groupId);
                      }
                    },
                  ),
                ],

                const SizedBox(height: 24),

                ResponsiveDialogActions(

                  secondary: TextButton(

                    onPressed: _isSaving ? null : () => Navigator.pop(context),

                    child: const Text('Cancel'),

                  ),

                  primary: ElevatedButton(

                    onPressed: _isSaving ? null : _createActivity,

                    child: _isSaving

                        ? const SizedBox(

                            width: 20,

                            height: 20,

                            child: CircularProgressIndicator(

                              strokeWidth: 2,

                              color: Colors.white,

                            ),

                          )

                        : const Text('Create Activity'),

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}

