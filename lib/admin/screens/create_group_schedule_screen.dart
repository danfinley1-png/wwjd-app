import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gift_reminder_utils.dart';
import '../models/group_schedule.dart';
import '../models/ministry_group.dart';
import '../providers/admin_providers.dart';

/// Org admin form for a recurring group spiritual practice.
class CreateGroupScheduleScreen extends ConsumerStatefulWidget {
  const CreateGroupScheduleScreen({
    super.key,
    required this.orgId,
    required this.group,
    required this.organizationName,
  });

  final String orgId;
  final MinistryGroup group;
  final String organizationName;

  @override
  ConsumerState<CreateGroupScheduleScreen> createState() =>
      _CreateGroupScheduleScreenState();
}

class _CreateGroupScheduleScreenState
    extends ConsumerState<CreateGroupScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _practiceTextController = TextEditingController();
  final _practiceLinkController = TextEditingController();
  final _timeController = TextEditingController(text: '07:00');

  GroupScheduleRecurrence _recurrence = GroupScheduleRecurrence.daily;
  final Set<String> _selectedDays = {};
  final List<String> _times = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _practiceTextController.dispose();
    _practiceLinkController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parsed = GiftReminderUtils.parseTime(_timeController.text);
    final picked = await showTimePicker(
      context: context,
      initialTime: parsed,
    );
    if (picked == null) return;
    setState(() {
      _timeController.text = GiftReminderUtils.formatStoredTime(picked);
    });
  }

  void _addTime() {
    final normalized = GiftReminderUtils.formatStoredTime(
      GiftReminderUtils.parseTime(_timeController.text),
    );
    if (_times.contains(normalized)) return;
    setState(() {
      _times.add(normalized);
      _times.sort();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one daily time.')),
      );
      return;
    }
    if (_recurrence == GroupScheduleRecurrence.weekly &&
        _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one day of the week.')),
      );
      return;
    }

    final practiceText = _practiceTextController.text.trim();
    final practiceLink = _practiceLinkController.text.trim();
    if (practiceText.isEmpty && practiceLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add practice text or a link to the prayer.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(groupScheduleServiceProvider).createSchedule(
            orgId: widget.orgId,
            group: widget.group,
            organizationName: widget.organizationName,
            title: _titleController.text,
            description: _descriptionController.text,
            times: _times,
            recurrence: _recurrence,
            daysOfWeek: _selectedDays.toList(),
            practiceText: practiceText.isEmpty ? null : practiceText,
            practiceLink: practiceLink.isEmpty ? null : practiceLink,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create schedule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New group practice'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Shared practice for ${widget.group.name}. Only members who '
              'have accepted the group invitation will receive this schedule.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.45),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Morning Angelus',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Short description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _practiceTextController,
              decoration: const InputDecoration(
                labelText: 'Prayer or practice text',
                hintText: 'Paste the text members should pray…',
                border: OutlineInputBorder(),
              ),
              maxLines: 6,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _practiceLinkController,
              decoration: const InputDecoration(
                labelText: 'Or link to practice',
                hintText: 'https://…',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            const Text(
              'Daily times',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _timeController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      border: OutlineInputBorder(),
                    ),
                    onTap: _pickTime,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addTime,
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_times.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _times.map((t) {
                  return InputChip(
                    label: Text(GiftReminderUtils.formatDisplayTime(t)),
                    onDeleted: () => setState(() => _times.remove(t)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Recurrence',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RadioListTile<GroupScheduleRecurrence>(
              title: const Text('Every day'),
              value: GroupScheduleRecurrence.daily,
              groupValue: _recurrence,
              onChanged: (v) => setState(() => _recurrence = v!),
            ),
            RadioListTile<GroupScheduleRecurrence>(
              title: const Text('Specific days of the week'),
              value: GroupScheduleRecurrence.weekly,
              groupValue: _recurrence,
              onChanged: (v) => setState(() => _recurrence = v!),
            ),
            if (_recurrence == GroupScheduleRecurrence.weekly)
              Wrap(
                spacing: 4,
                children: GiftReminderUtils.weekdayNames.map((day) {
                  final selected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day.substring(0, 3)),
                    selected: selected,
                    onSelected: (on) {
                      setState(() {
                        if (on) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
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
                  : const Icon(Icons.schedule),
              label: Text(_saving ? 'Saving…' : 'Create group schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
