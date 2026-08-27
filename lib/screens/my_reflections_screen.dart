import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';
import '../core/providers/app_providers.dart';
import '../core/providers/reflection_providers.dart';
import '../models/reflection_thread.dart';
import '../widgets/reflection_composer.dart';
import 'reflection_detail_screen.dart';

class MyReflectionsScreen extends ConsumerWidget {
  const MyReflectionsScreen({super.key});

  static final _dateFormat = DateFormat('MMM d, yyyy · h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(reflectionThreadsStreamProvider);
    final user = ref.watch(authServiceProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reflections'),
        centerTitle: true,
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openNewReflection(context),
              icon: const Icon(Icons.add),
              label: const Text('New reflection'),
            ),
      body: user == null
          ? _signedOutBody(context)
          : threadsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load reflections:\n$err',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (threads) {
                if (threads.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 72,
                            color: AppColors.primaryMaroon.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No reflections yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Capture private thoughts, prayers, and insights.\n'
                            'Only you can see them.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _openNewReflection(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Write a reflection'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: threads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    return _ThreadCard(
                      thread: thread,
                      dateFormat: _dateFormat,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ReflectionDetailScreen(
                              threadId: thread.id,
                            ),
                          ),
                        );
                      },
                      onDelete: () => _confirmDeleteThread(context, ref, thread),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _signedOutBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Sign in to keep private reflections',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your reflections are stored securely and visible only to you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  void _openNewReflection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const _NewReflectionScreen(),
      ),
    );
  }

  Future<void> _confirmDeleteThread(
    BuildContext context,
    WidgetRef ref,
    ReflectionThread thread,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reflection?'),
        content: Text(
          'Delete "${thread.displayTitle}" and all ${thread.entryCount} '
          '${thread.entryCount == 1 ? 'entry' : 'entries'}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(reflectionServiceProvider).deleteThread(thread.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reflection deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.dateFormat,
    required this.onTap,
    required this.onDelete,
  });

  final ReflectionThread thread;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final when = thread.updatedAt ?? thread.createdAt;
    final subtitle = thread.lastEntryPreview?.trim();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.displayTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (thread.sourceLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        thread.sourceLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryMaroon.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (when != null) dateFormat.format(when),
                        '${thread.entryCount} ${thread.entryCount == 1 ? 'entry' : 'entries'}',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade700,
                tooltip: 'Delete reflection',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewReflectionScreen extends ConsumerStatefulWidget {
  const _NewReflectionScreen();

  @override
  ConsumerState<_NewReflectionScreen> createState() =>
      _NewReflectionScreenState();
}

class _NewReflectionScreenState extends ConsumerState<_NewReflectionScreen> {
  bool _busy = false;

  Future<void> _save({String? title, required String body}) async {
    setState(() => _busy = true);
    try {
      final thread = await ref.read(reflectionServiceProvider).createReflection(
            title: title,
            body: body,
          );
      if (!mounted) return;
      Navigator.pop(context);
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ReflectionDetailScreen(threadId: thread.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Reflection'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Private to you. Add a title if you like, then write your reflection.',
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 20),
          ReflectionComposer(
            busy: _busy,
            onSubmit: _save,
          ),
        ],
      ),
    );
  }
}
