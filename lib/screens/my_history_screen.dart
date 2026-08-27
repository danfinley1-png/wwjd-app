import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/history_conversations.dart';
import '../core/providers/app_providers.dart';
import '../models/chat_message.dart';
import '../widgets/share_actions_bar.dart';
import '../widgets/linked_markdown_body.dart';

class MyHistoryScreen extends ConsumerStatefulWidget {
  const MyHistoryScreen({super.key});

  @override
  ConsumerState<MyHistoryScreen> createState() => _MyHistoryScreenState();
}

class _MyHistoryScreenState extends ConsumerState<MyHistoryScreen> {
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadHistory());
  }

  Future<void> _reloadHistory() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      await ref.read(sessionHistoryProvider.notifier).loadSessionFromFirebase();
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _parseConversations(List<ChatMessage> messages) {
    return parseHistoryConversations(messages);
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
      await _reloadHistory();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload history',
            onPressed: _isLoading ? null : _reloadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Could not load history',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _reloadHistory,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : conversations.isEmpty
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
                  : RefreshIndicator(
                      onRefresh: _reloadHistory,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conv = conversations[index];
                          final question = conv['question'] as String;
                          final responses = conv['responses'] as List<String>;
                          final createdAt = conv['createdAt'] as DateTime;
                          final responseLabel = responses.length == 1
                              ? '1 response'
                              : '${responses.length} responses';
                          final dateLabel = _formatCreatedDate(createdAt);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  title: Text(
                                    question,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
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
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (responses.isNotEmpty) Text(responseLabel),
                                      ],
                                    ),
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
                                            final isDelve = resp.toLowerCase().contains('delve') ||
                                                resp.length > 600;
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (idx > 0) const SizedBox(height: 24),
                                                Text(
                                                  isDelve
                                                      ? 'Deeper Reflections'
                                                      : 'WWJD Wisdom Sharing',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                LinkedMarkdownBody(data: resp),
                                              ],
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (responses.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 0, 8, 12),
                                    child: ShareActionsBar(
                                      question: question,
                                      response: responses.join('\n\n---\n\n'),
                                      onDelete: () => _confirmDelete(question),
                                      deleteTooltip: 'Delete conversation',
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
