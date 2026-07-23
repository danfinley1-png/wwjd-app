// lib/screens/sharing_my_gifts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';
import '../create_activity_dialog.dart';
import '../models/gift_activity.dart';
import '../widgets/auth_layout.dart';
import '../widgets/share_button.dart';
import 'activity_detail_screen.dart';

class SharingMyGiftsScreen extends ConsumerStatefulWidget {
  const SharingMyGiftsScreen({super.key});

  @override
  ConsumerState<SharingMyGiftsScreen> createState() => _SharingMyGiftsScreenState();
}

class _SharingMyGiftsScreenState extends ConsumerState<SharingMyGiftsScreen> {
  @override
  Widget build(BuildContext context) {
    final giftService = ref.watch(giftServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sharing My Gifts'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<GiftActivity>>(
        stream: giftService.getUserGiftsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading gifts:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final activities = snapshot.data ?? [];

          if (activities.isEmpty) {
            return const Center(
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
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: Checkbox(
                    value: activity.isCompleted,
                    onChanged: (_) async {
                      await giftService.toggleComplete(activity);
                    },
                  ),
                  title: Text(
                    activity.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: activity.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    activity.description.length > 60
                        ? '${activity.description.substring(0, 60)}...'
                        : activity.description,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Remove activity',
                        onPressed: () => _confirmRemove(activity),
                      ),
                      ShareButton(
                        question: activity.linkedQuestionText ?? 'Activity: ${activity.title}',
                        response: _shareResponseFor(activity),
                        title: activity.title,
                      ),
                    ],
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
                          if (activity.note != null && activity.note!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text('Note:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(activity.note!),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.edit),
                                label: const Text('Open'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ActivityDetailScreen(
                                        activity: activity,
                                        onUpdate: (updated) {
                                          giftService.saveGift(updated);
                                        },
                                      ),
                                    ),
                                  );
                                },
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => CreateActivityDialog(
              onActivityCreated: () {
                // StreamBuilder will automatically refresh
              },
            ),
          );
        },
        label: const Text('Add an Activity'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmRemove(GiftActivity activity) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => ResponsiveAuthDialog(
        title: const Text('Remove Activity?'),
        content: Text(
          'What would you like to do with "${activity.title}"?',
        ),
        actions: AuthDialogActions(
          actions: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'history'),
              icon: const Icon(Icons.history),
              label: const Text('Move to My History'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Permanently'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    try {
      if (choice == 'history') {
        final added = await ref.read(giftServiceProvider).moveToHistory(
              activity,
              ref.read(historyServiceProvider),
            );
        await ref.read(sessionHistoryProvider.notifier).loadSessionFromFirebase();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                added
                    ? 'Moved to My History'
                    : 'Removed from gifts (already in My History)',
              ),
            ),
          );
        }
      } else if (choice == 'delete') {
        await ref.read(giftServiceProvider).deleteGift(activity.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activity deleted permanently')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove activity: $e')),
        );
      }
    }
  }

  String _shareResponseFor(GiftActivity activity) {
    final base = activity.linkedResponseText ?? activity.description;
    if (activity.note == null || activity.note!.trim().isEmpty) return base;
    return '$base\n\n**Note:** ${activity.note!.trim()}';
  }
}
