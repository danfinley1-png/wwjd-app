// lib/my_history_screen.dart
import 'package:flutter/material.dart';

class MyHistoryScreen extends StatefulWidget {
  final List<dynamic> savedMessages;

  const MyHistoryScreen({super.key, required this.savedMessages});

  @override
  State<MyHistoryScreen> createState() => _MyHistoryScreenState();
}

class _MyHistoryScreenState extends State<MyHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('My History')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Previous conversations from this session\nTap any card to expand',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          const Divider(),
          Expanded(
            child: widget.savedMessages.isEmpty
                ? const Center(
                    child: Text(
                      'No conversations saved yet.\n\nAsk some questions in Seeking God\'s Wisdom.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.savedMessages.length,
                    itemBuilder: (context, index) {
                      final msg = widget.savedMessages[index] as dynamic;
                      if (msg.text.contains("Welcome to Seeking God's Wisdom")) {
                        return const SizedBox.shrink(); // Skip welcome
                      }

                      final isUser = msg.isUser ?? false;
                      final text = msg.text ?? '';

                      // Preview for compact view
                      final preview = text.length > 100 
                          ? text.substring(0, 100) + '...' 
                          : text;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ExpansionTile(
                          title: Text(
                            isUser ? "Question" : "WWJD Response",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(preview),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: SelectableText(
                                text,
                                style: const TextStyle(fontSize: 16.2, height: 1.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}