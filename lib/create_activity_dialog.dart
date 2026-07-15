// lib/create_activity_dialog.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/gift_activity.dart';
import '../core/services/gift_service.dart';
import '../walk_together_screen.dart';   // ← Add this import at the top

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

  final List<String> _frequencies = ['Daily', 'Weekly', 'Monthly', 'One-time'];
  String _shareDestination = 'none'; // none, community, group, individual, list


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
      linkedQuestionId: null,
      frequency: _frequency,
      hasReminder: _hasReminder,
      isCompleted: false,
      userId: FirebaseAuth.instance.currentUser?.uid,
    );

    globalGiftActivities.add(activity);
    print('DEBUG: Creating activity - Share destination: $_shareDestination');

    // Handle sharing
    if (_shareDestination != 'none') {
      if (_shareDestination == 'community') {
        WalkTogetherScreen.addSharedJourney({
          'id': activity.id,
          'title': 'Sharing My Gifts: ${activity.title}',
          'question': 'Activity: ${activity.title}',
          'response': activity.description ?? '',
          'upvotes': 0,
          'timestamp': DateTime.now(),
          'shareType': 'community',
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared to Walk Together!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share to $_shareDestination - will be implemented next')),
        );
      }
    }

    widget.onActivityCreated?.call();

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added: $title')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFFF8F0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create New Activity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Add to Sharing My Gifts Plan', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),

              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Activity Title',
                  hintText: 'e.g. Daily Gratitude Whisper',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Write a short reflection...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
                items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (val) => setState(() => _frequency = val!),
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                title: const Text('Enable Reminder'),
                value: _hasReminder,
                onChanged: (val) => setState(() => _hasReminder = val),
                contentPadding: EdgeInsets.zero,
              ),

              const Text('Share Activity', style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<String>(
                title: const Text('Do not share'),
                value: 'none',
                groupValue: _shareDestination,
                onChanged: (val) => setState(() => _shareDestination = val!),
              ),
              RadioListTile<String>(
                title: const Text('Walk Together (Community)'),
                value: 'community',
                groupValue: _shareDestination,
                onChanged: (val) => setState(() => _shareDestination = val!),
              ),
              RadioListTile<String>(
                title: const Text('Specific Group'),
                value: 'group',
                groupValue: _shareDestination,
                onChanged: (val) => setState(() => _shareDestination = val!),
              ),
              RadioListTile<String>(
                title: const Text('Individual'),
                value: 'individual',
                groupValue: _shareDestination,
                onChanged: (val) => setState(() => _shareDestination = val!),
              ),
              RadioListTile<String>(
                title: const Text('Custom List'),
                value: 'list',
                groupValue: _shareDestination,
                onChanged: (val) => setState(() => _shareDestination = val!),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _createActivity,
                    child: const Text('Create Activity'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}