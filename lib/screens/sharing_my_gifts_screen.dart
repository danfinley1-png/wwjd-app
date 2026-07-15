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
    print('DEBUG: Loaded ${_activities.length} activities locally');
  }

  void _updateActivity(GiftActivity updated) {
    setState(() {
      final index = _activities.indexWhere((a) => a.id == updated.id);
      if (index != -1) {
        _activities[index] = updated;
        globalGiftActivities[index] = updated; // Sync global
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
        SnackBar(content: Text('Share to $choice - coming in next phase')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: Build - ${_activities.length} activities');
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
                  Text('Tap + to add one', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
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
                  child: ListTile(
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
                    title: Text(activity.title),
                    subtitle: Text(
                      activity.description.length > 80 
                          ? '${activity.description.substring(0, 80)}...' 
                          : activity.description,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () => _showShareOptions(activity),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActivityDetailScreen(
                            activity: activity,
                            onUpdate: _updateActivity,
                          ),
                        ),
                      ).then((_) => _loadActivities());
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => CreateActivityDialog(
              onActivityCreated: () {
                _loadActivities(); // Refresh after creation
              },
            ),
          );
        },
        label: const Text('Add an Activity'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}