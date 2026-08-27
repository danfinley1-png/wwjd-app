import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gift_reminder_utils.dart';
import '../../core/mobile_touch.dart';
import '../../core/user_text_input.dart';
import '../../widgets/group_brand_mark.dart';
import '../../widgets/prayer_link_picker.dart';
import '../models/group_gift.dart';
import '../models/ministry_group.dart';
import '../models/organization.dart';
import '../providers/admin_providers.dart';

/// Org / overall admin form for a group-owned My Gifts activity.
class CreateGroupGiftScreen extends ConsumerStatefulWidget {
  const CreateGroupGiftScreen({
    super.key,
    required this.orgId,
    required this.group,
    required this.organizationName,
    this.existing,
  });

  final String orgId;
  final MinistryGroup group;
  final String organizationName;
  final GroupGift? existing;

  @override
  ConsumerState<CreateGroupGiftScreen> createState() =>
      _CreateGroupGiftScreenState();
}

class _CreateGroupGiftScreenState extends ConsumerState<CreateGroupGiftScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String _frequency = 'Daily';
  String? _linkedPrayerId;
  bool _hasDefaultTime = false;
  TimeOfDay _defaultTime = GiftReminderUtils.defaultTime;
  bool _active = true;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _frequency = existing?.frequency ?? 'Daily';
    if (!GroupGift.frequencies.contains(_frequency)) {
      _frequency = 'Daily';
    }
    _linkedPrayerId = existing?.linkedPrayerId;
    final time = existing?.specificTime?.trim();
    if (time != null && time.isNotEmpty) {
      _hasDefaultTime = true;
      _defaultTime = GiftReminderUtils.parseTime(time);
    }
    _active = existing?.active ?? true;
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
      initialTime: _defaultTime,
    );
    if (picked == null) return;
    setState(() => _defaultTime = picked);
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description is required.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(groupGiftServiceProvider);
      final time = _hasDefaultTime
          ? GiftReminderUtils.formatStoredTime(_defaultTime)
          : null;
      if (_isEditing) {
        final existing = widget.existing!;
        await service.updateGift(
          existing.copyWith(
            title: _titleController.text,
            description: _descriptionController.text,
            linkedPrayerId: _linkedPrayerId ?? '',
            frequency: _frequency,
            specificTime: time ?? '',
            active: _active,
            logoUrl: Organization.resolveLogoUrl(
              organizationLogoUrl: ref
                  .read(organizationProvider(widget.orgId))
                  .valueOrNull
                  ?.resolvedLogoUrl,
              fallback: widget.group.logoUrl,
            ),
            groupName: widget.group.name,
            organizationName: widget.organizationName,
          ),
        );
        if (_active != existing.active) {
          await service.setActive(gift: existing.copyWith(active: _active), active: _active);
        }
      } else {
        await service.createGift(
          orgId: widget.orgId,
          group: widget.group,
          organizationName: widget.organizationName,
          title: _titleController.text,
          description: _descriptionController.text,
          frequency: _frequency,
          linkedPrayerId: _linkedPrayerId,
          specificTime: time,
          active: _active,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save group Gift: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgLogo = Organization.resolveLogoUrl(
      organizationLogoUrl:
          ref.watch(organizationProvider(widget.orgId)).valueOrNull?.resolvedLogoUrl,
      fallback: widget.group.logoUrl,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit group Gift' : 'Create group Gift'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                GroupBrandMark(
                  groupName: widget.group.name,
                  logoUrl: orgLogo,
                  orgId: widget.orgId,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Shared My Gifts activity for ${widget.group.name}. '
                    'Accepted members receive it when Active. Members cannot '
                    'change the shared title or description.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            UserTextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Live Vertical morning offering',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            UserTextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Action steps members should take…',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            PrayerLinkPicker(
              selectedPrayerId: _linkedPrayerId,
              enabled: !_saving,
              onChanged: (id) => setState(() => _linkedPrayerId = id),
            ),
            const SizedBox(height: 16),
            MobileFriendlyDropdown(
              label: 'Frequency',
              value: _frequency,
              items: GroupGift.frequencies,
              onChanged: (val) => setState(() => _frequency = val),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default time (optional)'),
              subtitle: Text(
                _hasDefaultTime
                    ? GiftReminderUtils.formatDisplayTime(
                        GiftReminderUtils.formatStoredTime(_defaultTime),
                      )
                    : 'No default reminder time',
              ),
              value: _hasDefaultTime,
              onChanged: (on) => setState(() => _hasDefaultTime = on),
            ),
            if (_hasDefaultTime)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    GiftReminderUtils.formatDisplayTime(
                      GiftReminderUtils.formatStoredTime(_defaultTime),
                    ),
                  ),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text(
                'When Active, this Gift is added to current Accepted members '
                'and to anyone who later accepts this group.',
              ),
              value: _active,
              onChanged: (on) => setState(() => _active = on),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.card_giftcard),
              label: Text(
                _saving
                    ? 'Saving…'
                    : _isEditing
                        ? 'Save group Gift'
                        : 'Create group Gift',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
