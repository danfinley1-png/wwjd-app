  // lib/walk_together_screen.dart
import 'package:flutter/material.dart';

class WalkTogetherScreen extends StatefulWidget {
  final Map<String, dynamic>? sharedJourney;

  const WalkTogetherScreen({super.key, this.sharedJourney});

  @override
  State<WalkTogetherScreen> createState() => _WalkTogetherScreenState();
}

class _WalkTogetherScreenState extends State<WalkTogetherScreen> {
  final List<Map<String, dynamic>> _sharedJourneys = [];

  @override
  void initState() {
    super.initState();
    if (widget.sharedJourney != null) {
      _sharedJourneys.add(widget.sharedJourney!);
    }
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
            child: _sharedJourneys.isEmpty
                ? const Center(
                    child: Text(
                      'No journeys shared yet.\n\nShare from a response in Seeking God\'s Wisdom.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _sharedJourneys.length,
                    itemBuilder: (context, index) {
                      final journey = _sharedJourneys[index];
                      final questionPreview = journey['question'].toString().length > 80 
                          ? journey['question'].toString().substring(0, 80) + '...' 
                          : journey['question'].toString();
                      final responsePreview = journey['response'].toString().length > 100 
                          ? journey['response'].toString().substring(0, 100) + '...' 
                          : journey['response'].toString();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(journey['title'] ?? 'Shared Journey'),
                          subtitle: Text("Q: $questionPreview\nResponse: $responsePreview"),
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
      useSafeArea: true,                    // Important for iPhone notch/status bar
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: true,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), // Extra bottom padding for iPhone
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  journey['title'] ?? 'Shared Journey',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text('Question:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(journey['question'] ?? '', style: const TextStyle(fontSize: 16, height: 1.5)),
                const SizedBox(height: 24),
                const Text('WWJD Response:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(journey['response'] ?? '', style: const TextStyle(fontSize: 16, height: 1.5)),
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