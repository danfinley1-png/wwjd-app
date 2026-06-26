// lib/screens/activity_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/gift_activity.dart';
import '../core/app_colors.dart';

class ActivityDetailScreen extends StatefulWidget {
  final GiftActivity activity;
  final Function(GiftActivity) onUpdate;

  const ActivityDetailScreen({
    super.key,
    required this.activity,
    required this.onUpdate,
  });

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  late GiftActivity _activity;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _noteController.text = _activity.note ?? '';
  }

  void _toggleComplete() {
    final updated = GiftActivity(
      id: _activity.id,
      title: _activity.title,
      description: _activity.description,
      linkedQuestionId: _activity.linkedQuestionId,
      frequency: _activity.frequency,
      specificTime: _activity.specificTime,
      daysOfWeek: _activity.daysOfWeek,
      dueDate: _activity.dueDate,
      isCompleted: !_activity.isCompleted,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      completedAt: !_activity.isCompleted ? DateTime.now() : null,
      hasReminder: _activity.hasReminder,
      userId: _activity.userId,
    );
    setState(() => _activity = updated);
    widget.onUpdate(updated);
  }

  void _saveNote() {
    final updated = GiftActivity(
      id: _activity.id,
      title: _activity.title,
      description: _activity.description,
      linkedQuestionId: _activity.linkedQuestionId,
      frequency: _activity.frequency,
      specificTime: _activity.specificTime,
      daysOfWeek: _activity.daysOfWeek,
      dueDate: _activity.dueDate,
      isCompleted: _activity.isCompleted,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      completedAt: _activity.completedAt,
      hasReminder: _activity.hasReminder,
      userId: _activity.userId,
    );
    setState(() => _activity = updated);
    widget.onUpdate(updated);
  }

  @override
  Widget build(BuildContext context) {
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
            // Checkbox and Title
            Row(
              children: [
                Checkbox(
                  value: _activity.isCompleted,
                  onChanged: (_) => _toggleComplete(),
                ),
                Expanded(
                  child: Text(
                    _activity.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_activity.frequency} ${ _activity.specificTime != null ? 'at ${_activity.specificTime}' : ''}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Divider(height: 40),

            // Action Description
            const Text('Action Steps', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_activity.description, style: const TextStyle(fontSize: 16.2, height: 1.6)),

            const SizedBox(height: 32),

            // Collapsible Note
            const Text('My Reflection Note', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Add a short reflection (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _saveNote(),
            ),

            const SizedBox(height: 32),

            // Linked Question (if exists)
            if (_activity.linkedQuestionId != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Linked WWJD Response', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  // TODO: Button to view original response
                  TextButton.icon(
                    icon: const Icon(Icons.menu_book),
                    label: const Text('View Original Guidance'),
                    onPressed: () {
                      // Navigate back or show dialog with linked response
                    },
                  ),
                ],
              ),

            const SizedBox(height: 40),

            // Share & Invite
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share Anonymously'),
                  onPressed: () {
                    // Share to Walk Together
                  },
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Invite Others'),
                  onPressed: () {
                    // Future: Share link or invite group
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