// lib/screens/sharing_my_gifts_screen.dart
import 'package:flutter/material.dart';
import '../models/gift_activity.dart';
import '../core/app_colors.dart';
import 'activity_detail_screen.dart';
import '../create_activity_dialog.dart';
import '../core/services/gift_service.dart';
import '../walk_together_screen.dart';

class SharingMyGiftsScreen extends StatefulWidget {
  const SharingMyGiftsScreen({super.key});

  @override
  State<SharingMyGiftsScreen> createState() => _SharingMyGiftsScreenState();
}

class _SharingMyGiftsScreenState extends State<SharingMyGiftsScreen> {
  List<GiftActivity> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  void _loadActivities() {
    setState(() {
      _activities = List.from(globalGiftActivities);
    });
  }

  void _updateActivity(GiftActivity updated) {
    setState(() {
      final index = _activities.indexWhere((a) => a.id == updated.id);
      if (index != -1) {
        _activities[index] = updated;
        globalGiftActivities[index] = updated;
      }
    });
  }

  Future<void> _showShareOptions(GiftActivity activity) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Walk Together (Community)'),
              onTap: () => Navigator.pop(ctx, 'community'),
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Specific Group'),
              onTap: () => Navigator.pop(ctx, 'group'),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Individual'),
              onTap: () => Navigator.pop(ctx, 'individual'),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Custom List'),
              onTap: () => Navigator.pop(ctx, 'list'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'community') {
      WalkTogetherScreen.addSharedJourney({
        'id': activity.id,
        'title': activity.title,
        'question': 'Activity: ${activity.title}',
        'response': activity.description ?? 'No description provided.',
        'note': activity.note ?? '',
        'upvotes': 0,
        'timestamp': DateTime.now(),
        'hasGiftsLink': true,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shared anonymously to Walk Together!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share to $choice — coming soon')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sharing My Gifts'),
        centerTitle: true,
      ),
      body: _activities.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard, size: 80, color: Colors.grey),
                  SizedBox(height: 24),
                  Text('No activities yet', style: TextStyle(fontSize: 20)),
                  SizedBox(height: 8),
                  Text('Tap + to add one', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                final activity = _activities[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: Checkbox(
                      value: activity.isCompleted,
                      onChanged: (_) => _updateActivity(
                        GiftActivity(
                          id: activity.id,
                          title: activity.title,
                          description: activity.description,
                          linkedQuestionId: activity.linkedQuestionId,
                          frequency: activity.frequency,
                          specificTime: activity.specificTime,
                          daysOfWeek: activity.daysOfWeek,
                          dueDate: activity.dueDate,
                          isCompleted: !activity.isCompleted,
                          note: activity.note,
                          completedAt: !activity.isCompleted ? DateTime.now() : null,
                          hasReminder: activity.hasReminder,
                          userId: activity.userId,
                        ),
                      ),
                    ),
                    title: Text(activity.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      activity.description.length > 60
                          ? '${activity.description.substring(0, 60)}...'
                          : activity.description,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(activity.description),
                            if (activity.note?.isNotEmpty == true) ...[
                              const SizedBox(height: 12),
                              const Text('Note:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(activity.note!),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                  onPressed: () => _showShareOptions(activity),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => CreateActivityDialog(
              onActivityCreated: _loadActivities,
            ),
          );
        },
        label: const Text('Add an Activity'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}