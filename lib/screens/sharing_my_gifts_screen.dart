// lib/screens/sharing_my_gifts_screen.dart
import 'package:flutter/material.dart';
import '../models/gift_activity.dart';
import '../core/app_colors.dart';
import 'activity_detail_screen.dart';

class SharingMyGiftsScreen extends StatefulWidget {
  const SharingMyGiftsScreen({super.key});

  @override
  State<SharingMyGiftsScreen> createState() => _SharingMyGiftsScreenState();
}

class _SharingMyGiftsScreenState extends State<SharingMyGiftsScreen> {
  List<GiftActivity> get _activities => globalGiftActivities;

  @override
  void initState() {
    super.initState();
    print('DEBUG: SharingMyGiftsScreen loaded with ${_activities.length} activities');
  }

  void _updateActivity(GiftActivity updated) {
    setState(() {
      final index = _activities.indexWhere((a) => a.id == updated.id);
      if (index != -1) {
        _activities[index] = updated;
      }
    });
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
                  Text(
                    'No activities yet',
                    style: TextStyle(fontSize: 20),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to add one or use "Add to My Gifts Plan"',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
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
                      activity.specificTime != null
                          ? '${activity.frequency} at ${activity.specificTime}'
                          : activity.frequency,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActivityDetailScreen(
                            activity: activity,
                            onUpdate: _updateActivity,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Placeholder for manual add - can expand later
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}