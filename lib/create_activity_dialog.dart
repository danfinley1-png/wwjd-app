// lib/create_activity_dialog.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/gift_activity.dart';
import 'walk_together_screen.dart';

class CreateActivityDialog extends StatefulWidget {
  final VoidCallback? onActivityCreated;

  const CreateActivityDialog({super.key, this.onActivityCreated});

  @override
  State<CreateActivityDialog> createState() => _CreateActivityDialogState();
}

class _CreateActivityDialogState extends State<CreateActivityDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _frequency = 'Daily';
  bool _hasReminder = true;
  bool _shareImmediately = false;

  final List<String> _frequencies = ['Daily', 'Weekly', 'Monthly', 'One-time'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

      void _createActivity() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    final String description = _descriptionController.text.trim().isNotEmpty 
        ? _descriptionController.text.trim() 
        : "Regular practice of this gift to grow in faith and service.";

    final activity = GiftActivity(
      id: const Uuid().v4(),
      title: title,
      description: description,
      linkedQuestionId: 'custom',
      frequency: _frequency,
      hasReminder: _hasReminder,
      isCompleted: false,
    );

    globalGiftActivities.add(activity);

    if (widget.onActivityCreated != null) widget.onActivityCreated!();

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added: $title')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFFF8F0), // warm parchment tone
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create New Activity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Add to Sharing My Gifts Plan', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 24),

            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Activity Title',
                hintText: 'e.g. Daily Gratitude Whisper',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Write a short reflection on how faith is helping you...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Frequency
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
              items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) => setState(() => _frequency = val!),
            ),
            const SizedBox(height: 12),

            // Reminder
            SwitchListTile(
              title: const Text('Enable Reminder'),
              value: _hasReminder,
              onChanged: (val) => setState(() => _hasReminder = val),
              contentPadding: EdgeInsets.zero,
            ),

            // Share immediately
            CheckboxListTile(
              title: const Text('Share to Walk Together immediately'),
              value: _shareImmediately,
              onChanged: (val) => setState(() => _shareImmediately = val!),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _createActivity, child: const Text('Create Activity')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}