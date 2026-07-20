// lib/walk_together_screen.dart
import 'package:flutter/material.dart';

class WalkTogetherScreen extends StatefulWidget {
  final Map<String, dynamic>? sharedJourney;

  const WalkTogetherScreen({super.key, this.sharedJourney});

  static void addSharedJourney(Map<String, dynamic> journey) {
    final exists = _sharedJourneys.any((j) => 
        j['id'] == journey['id'] && j['question'] == journey['question']);
    if (!exists) {
      _sharedJourneys.add(journey);
      sharedJourneysNotifier.value = List.from(_sharedJourneys);
    }
  }

  static List<Map<String, dynamic>> getSharedJourneys() {
    return List.from(_sharedJourneys);
  }

  static final List<Map<String, dynamic>> _sharedJourneys = [];
  static final ValueNotifier<List<Map<String, dynamic>>> sharedJourneysNotifier = 
      ValueNotifier<List<Map<String, dynamic>>>([]);

  @override
  State<WalkTogetherScreen> createState() => _WalkTogetherScreenState();
}

class _WalkTogetherScreenState extends State<WalkTogetherScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.sharedJourney != null) {
      WalkTogetherScreen.addSharedJourney(widget.sharedJourney!);
    }
  }

  void _upvoteJourney(Map<String, dynamic> journey) {
    final index = WalkTogetherScreen._sharedJourneys.indexWhere((j) => j['id'] == journey['id']);
    if (index != -1) {
      WalkTogetherScreen._sharedJourneys[index]['upvotes'] = 
          (WalkTogetherScreen._sharedJourneys[index]['upvotes'] ?? 0) + 1;
      
      WalkTogetherScreen.sharedJourneysNotifier.value = 
          List.from(WalkTogetherScreen._sharedJourneys);
    }
  }

  List<Map<String, dynamic>> _getSortedJourneys(List<Map<String, dynamic>> journeys) {
    final sorted = List<Map<String, dynamic>>.from(journeys);
    sorted.sort((a, b) => (b['upvotes'] ?? 0).compareTo(a['upvotes'] ?? 0));
    return sorted;
  }

  void _openJourney(Map<String, dynamic> journey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                Text(journey['title'] ?? 'Shared Journey', 
                     style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                const Text('Question:', style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(journey['question'] ?? ''),
                const SizedBox(height: 24),

                const Text('WWJD Response:', style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(
                  journey['response'] ?? '',
                  style: const TextStyle(fontSize: 16, height: 1.55),
                ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Walk Together')),
        centerTitle: true,
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
              valueListenable: WalkTogetherScreen.sharedJourneysNotifier,
              builder: (context, journeys, child) {
                if (journeys.isEmpty) {
                  return const Center(
                    child: Text(
                      'No journeys shared yet.\n\nShare from Seeking God\'s Wisdom.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final sortedJourneys = _getSortedJourneys(journeys);
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedJourneys.length,
                  itemBuilder: (context, index) {
                    final journey = sortedJourneys[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(journey['title'] ?? 'Shared Journey'),
                        subtitle: Text(
                          (journey['question'] ?? '').toString().length > 80
                              ? '${(journey['question'] ?? '').toString().substring(0, 80)}...'
                              : (journey['question'] ?? ''),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${journey['upvotes'] ?? 0}'),
                            IconButton(
                              icon: const Icon(Icons.thumb_up, color: Colors.orange),
                              onPressed: () => _upvoteJourney(journey),
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
}