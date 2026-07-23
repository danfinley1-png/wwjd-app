import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/providers/app_providers.dart';
import '../models/chat_message.dart';
import '../widgets/share_button.dart';

class MyHistoryScreen extends ConsumerStatefulWidget {
  const MyHistoryScreen({super.key});

  @override
  ConsumerState<MyHistoryScreen> createState() => _MyHistoryScreenState();
}

class _MyHistoryScreenState extends ConsumerState<MyHistoryScreen> {
  List<Map<String, dynamic>> _parseConversations(List<ChatMessage> messages) {
    final conversations = <Map<String, dynamic>>[];
    var currentQuestion = '';
    var currentResponses = <String>[];
    DateTime? currentCreatedAt;

    for (final m in messages) {
      final text = m.text;
      if (text.isEmpty || text.contains("Welcome to Seeking God's Wisdom")) continue;
      if (text.contains('DELVE DEEPER MODE') || text.contains('NON-NEGOTIABLE')) continue;
      if (m.isStaticPrompt || m.isSpiritualNourishment) continue;

      if (m.isUser) {
        if (currentQuestion.isNotEmpty) {
          conversations.add({
            'question': currentQuestion,
            'responses': List<String>.from(currentResponses),
            'createdAt': currentCreatedAt ?? DateTime.now(),
          });
        }
        currentQuestion = text;
        currentResponses = [];
        currentCreatedAt = m.timestamp;
      } else if (currentQuestion.isNotEmpty) {
        currentResponses.add(text);
      }
    }

    if (currentQuestion.isNotEmpty) {
      conversations.add({
        'question': currentQuestion,
        'responses': List<String>.from(currentResponses),
        'createdAt': currentCreatedAt ?? DateTime.now(),
      });
    }

    conversations.sort(
      (a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime),
    );

    return conversations;
  }

  String _formatCreatedDate(DateTime createdAt) {
    return DateFormat.yMMMd().add_jm().format(createdAt);
  }

  Future<void> _confirmDelete(String question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: SizedBox(
          width: double.maxFinite,
          child: Text(
            question,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(historyServiceProvider).deleteConversation(question);
      await ref.read(sessionHistoryProvider.notifier).loadSessionFromFirebase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(sessionHistoryProvider);
    final conversations = _parseConversations(messages);

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
                final createdAt = conv['createdAt'] as DateTime;
                final responseLabel =
                    responses.length == 1 ? '1 response' : '${responses.length} responses';
                final dateLabel = _formatCreatedDate(createdAt);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: Text(
                      question,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateLabel,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          if (responses.isNotEmpty) Text(responseLabel),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete conversation',
                          onPressed: () => _confirmDelete(question),
                        ),
                        ShareButton(
                          question: question,
                          response: responses.join('\n\n---\n\n'),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...responses.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final resp = entry.value;
                              final isDelve = resp.toLowerCase().contains('delve') || resp.length > 600;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (idx > 0) const SizedBox(height: 24),
                                  Text(
                                    isDelve ? 'Deeper Reflections' : 'WWJD Wisdom Sharing',
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
                                ],
                              );
                            }),
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
}
