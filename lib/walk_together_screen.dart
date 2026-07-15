// lib/walk_together_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For ValueNotifier

class WalkTogetherScreen extends StatefulWidget {
  final Map<String, dynamic>? sharedJourney;

  const WalkTogetherScreen({super.key, this.sharedJourney});

  // Public static method for sharing from other screens
  static void addSharedJourney(Map<String, dynamic> journey) {
    bool alreadyShared = _WalkTogetherScreenState.sharedJourneysNotifier.value.any((j) => 
      j['question'] == journey['question'] && j['response'] == journey['response']
    );
    if (!alreadyShared) {
      final updated = List<Map<String, dynamic>>.from(_WalkTogetherScreenState.sharedJourneysNotifier.value);
      updated.add(journey);
      _WalkTogetherScreenState.sharedJourneysNotifier.value = updated;
    }
  }

  @override
  State<WalkTogetherScreen> createState() => _WalkTogetherScreenState();
}

class _WalkTogetherScreenState extends State<WalkTogetherScreen> {
  // Reactive list for cross-screen updates
  static final ValueNotifier<List<Map<String, dynamic>>> sharedJourneysNotifier = 
      ValueNotifier<List<Map<String, dynamic>>>([]);

  // Groups support
  static final List<String> _groups = [
    'My Family',
    'Parish Accountability',
    'Friends in Faith',
  ];

  static final Map<String, List<Map<String, dynamic>>> _groupActivities = {};

  @override
  void initState() {
    super.initState();
    if (widget.sharedJourney != null) {
      final newJourney = widget.sharedJourney!;
      bool alreadyShared = sharedJourneysNotifier.value.any((j) => 
        j['question'] == newJourney['question'] && j['response'] == newJourney['response']
      );
      if (!alreadyShared) {
        final updated = List<Map<String, dynamic>>.from(sharedJourneysNotifier.value);
        updated.add(newJourney);
        sharedJourneysNotifier.value = updated;
      }
    }
  }

  void _createGroup() {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Create New Group'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Group name (e.g. Bible Study Group)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty && !_groups.contains(name)) {
                  setState(() {
                    _groups.add(name);
                    _groupActivities[name] = [];
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Walk Together')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _createGroup,
            tooltip: 'Create Group',
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Community Journeys\nSupport each other in faith.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          const Divider(),
          Expanded(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: sharedJourneysNotifier,
              builder: (context, journeys, child) {
                return journeys.isEmpty
                    ? const Center(
                        child: Text(
                          'No journeys shared yet.\n\nShare from a response in Seeking God\'s Wisdom or create your own activity.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: journeys.length,
                        itemBuilder: (context, index) {
                          final journey = journeys[index];
                          final questionPreview = journey['question'].toString().length > 80 
                              ? journey['question'].toString().substring(0, 80) + '...' 
                              : journey['question'].toString();
                          final responsePreview = journey['response'].toString().length > 100 
                              ? journey['response'].toString().substring(0, 100) + '...' 
                              : journey['response'].toString();

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: null,
                              subtitle: Text(
                                journey['question'].toString().startsWith('Activity:') 
                                    ? "Sharing My Gifts\nActivity: ${journey['question'].toString().replaceFirst('Activity: ', '')}\nDescription: $responsePreview"
                                    : "Shared Wisdom\nQuestion: $questionPreview\nResponse: $responsePreview"
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${journey['upvotes'] ?? 0}'),
                                  IconButton(
                                    icon: const Icon(Icons.thumb_up),
                                    onPressed: () {
                                      setState(() {
                                        journey['upvotes'] = (journey['upvotes'] ?? 0) + 1;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              onTap: () => _openJourney(journey),
                            ),
                          );
                        },
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openJourney(Map<String, dynamic> journey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: true,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(journey['title'] ?? 'Shared Journey', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Activity:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(journey['question'] ?? 'No activity description'),
                const SizedBox(height: 24),
                const Text('WWJD Response:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(journey['response'] ?? ''),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}