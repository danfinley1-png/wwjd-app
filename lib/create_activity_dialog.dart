// lib/create_activity_dialog.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/gift_activity.dart';
import '../core/services/gift_service.dart';
import '../core/responsive_layout.dart';
import '../walk_together_screen.dart';

class CreateActivityDialog extends StatefulWidget {
  final VoidCallback? onActivityCreated;

  const CreateActivityDialog({super.key, this.onActivityCreated});

  @override
  State<CreateActivityDialog> createState() => _CreateActivityDialogState();
}

class _CreateActivityDialogState extends State<CreateActivityDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GiftService _giftService = GiftService();

  String _frequency = 'Daily';
  bool _hasReminder = true;
  String _shareDestination = 'none';
  bool _isSaving = false;

  final List<String> _frequencies = ['Daily', 'Weekly', 'Monthly', 'One-time'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

    try {
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
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await _giftService.saveGift(activity);

      // Optional community share
      if (_shareDestination == 'community') {
        WalkTogetherScreen.addSharedJourney({
          'id': activity.id,
          'title': 'Sharing My Gifts: ${activity.title}',
          'question': 'Activity: ${activity.title}',
          'response': activity.description,
          'upvotes': 0,
          'timestamp': DateTime.now(),
          'shareType': 'community',
        });
      }

      widget.onActivityCreated?.call();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_shareDestination == 'community'
                ? 'Added & shared to Walk Together: $title'
                : 'Added to Sharing My Gifts: $title'),
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
    return Dialog(
      backgroundColor: const Color(0xFFFFF8F0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: responsiveDialogMaxWidth(context),
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
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

              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Activity Title',
                  hintText: 'e.g. Daily Gratitude Whisper',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Write a short reflection or action steps...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Frequency dropdown (modern)
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                ),
                items: _frequencies
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _frequency = val);
                },
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                title: const Text('Enable Reminder'),
                value: _hasReminder,
                onChanged: (val) => setState(() => _hasReminder = val),
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 16),
              const Text(
                'Share Activity',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),

              // Modern radio buttons
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
                title: const Text('Specific Group (coming soon)'),
                value: 'group',
                groupValue: _shareDestination,
                onChanged: null, // disabled
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}