import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/share_button.dart';   // ← Add this import

class MyHistoryScreen extends StatelessWidget {
  final List<dynamic> messages;

  const MyHistoryScreen({super.key, this.messages = const []});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> conversations = [];

    String currentQuestion = '';
    List<String> currentResponses = [];

    for (final m in messages) {
      final text = _getText(m);
      if (text.isEmpty || text.contains("Welcome to Seeking God's Wisdom")) continue;

      if (text.contains("DELVE DEEPER MODE") || text.contains("NON-NEGOTIABLE")) continue;

      if (text.length < 300 && !text.toLowerCase().contains('dear friend') && !text.toLowerCase().contains('good ')) {
        if (currentQuestion.isNotEmpty) {
          conversations.add({
            'question': currentQuestion,
            'responses': List<String>.from(currentResponses),
          });
        }
        currentQuestion = text;
        currentResponses = [];
      } else {
        currentResponses.add(text);
      }
    }

    if (currentQuestion.isNotEmpty) {
      conversations.add({
        'question': currentQuestion,
        'responses': List<String>.from(currentResponses),
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My History'),
        centerTitle: true,
      ),
      body: conversations.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 24),
                  Text('No conversations yet', style: TextStyle(fontSize: 20)),
                  Text('Ask questions in Seeking God\'s Wisdom'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final question = conv['question'] as String;
                final responses = conv['responses'] as List<String>;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: const Text('Conversation', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(question.length > 60 ? '${question.substring(0, 60)}...' : question),
                    trailing: ShareButton(
                      question: question,
                      response: responses.join('\n\n---\n\n'),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('My Question:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(question, style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 24),
                            ...responses.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final resp = entry.value;
                              final isDelve = resp.toLowerCase().contains('delve') || resp.length > 600;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isDelve ? 'Deeper Reflections:' : 'WWJD Wisdom Sharing:',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  MarkdownBody(
                                    data: resp,
                                    onTapLink: (text, href, title) {
                                      if (href != null) launchUrl(Uri.parse(href));
                                    },
                                    styleSheet: MarkdownStyleSheet(
                                      p: const TextStyle(fontSize: 16, height: 1.55),
                                    ),
                                  ),
                                  if (idx < responses.length - 1) const SizedBox(height: 24),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _getText(dynamic m) {
    if (m == null) return '';
    if (m is Map) return m['text'] ?? '';
    try {
      return m.text ?? m.toString();
    } catch (_) {
      return m.toString();
    }
  }
}