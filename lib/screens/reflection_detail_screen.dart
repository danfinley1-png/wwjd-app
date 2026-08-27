import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';
import '../core/providers/reflection_providers.dart';
import '../models/reflection_entry.dart';
import '../models/reflection_thread.dart';
import '../widgets/reflection_composer.dart';
import '../widgets/reflection_source_link.dart';

class ReflectionDetailScreen extends ConsumerWidget {
  const ReflectionDetailScreen({
    super.key,
    required this.threadId,
  });

  final String threadId;

  static final _dateFormat = DateFormat('EEEE, MMM d, yyyy · h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadAsync = ref.watch(reflectionThreadStreamProvider(threadId));
    final entriesAsync = ref.watch(reflectionEntriesStreamProvider(threadId));

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: threadAsync.maybeWhen(
          data: (thread) => Text(
            thread?.displayTitle ?? 'Reflection',
            overflow: TextOverflow.ellipsis,
          ),
          orElse: () => const Text('Reflection'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete entire reflection',
            onPressed: () => _confirmDeleteThread(context, ref, threadAsync.valueOrNull),
          ),
        ],
      ),
      body: threadAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (thread) {
          if (thread == null) {
            return const Center(child: Text('Reflection not found.'));
          }

          return entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (entries) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (thread.title != null && thread.title!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        thread.title!.trim(),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryMaroon,
                            ),
                      ),
                    ),
                  Text(
                    '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'} · private',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  ReflectionSourceLink(thread: thread),
                  const SizedBox(height: 16),
                  ...entries.map(
                    (entry) => _EntryCard(
                      entry: entry,
                      dateFormat: _dateFormat,
                      onDelete: () => _confirmDeleteEntry(context, ref, entry),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Add to this reflection',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Continue the same topic with a new dated entry.',
                    style: TextStyle(color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  _AppendComposer(threadId: threadId),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteThread(
    BuildContext context,
    WidgetRef ref,
    ReflectionThread? thread,
  ) async {
    if (thread == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entire reflection?'),
        content: Text(
          'Delete "${thread.displayTitle}" and all its entries? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete all', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(reflectionServiceProvider).deleteThread(threadId);
      if (context.mounted) {
        Navigator.pop(context);
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

  Future<void> _confirmDeleteEntry(
    BuildContext context,
    WidgetRef ref,
    ReflectionEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text(
          'Remove this dated entry from the reflection thread? '
          'If it is the last entry, the whole reflection will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete entry', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final threadRemoved = await ref.read(reflectionServiceProvider).deleteEntry(
            threadId: threadId,
            entryId: entry.id,
          );
      if (!context.mounted) return;

      if (threadRemoved) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.dateFormat,
    required this.onDelete,
  });

  final ReflectionEntry entry;
  final DateFormat dateFormat;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final when = entry.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.parchment,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    when != null ? dateFormat.format(when) : 'Entry',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryMaroon.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red.shade700,
                  tooltip: 'Delete entry',
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              entry.body,
              style: const TextStyle(height: 1.55, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppendComposer extends ConsumerStatefulWidget {
  const _AppendComposer({required this.threadId});

  final String threadId;

  @override
  ConsumerState<_AppendComposer> createState() => _AppendComposerState();
}

class _AppendComposerState extends ConsumerState<_AppendComposer> {
  bool _busy = false;

  Future<void> _append({String? title, required String body}) async {
    setState(() => _busy = true);
    try {
      await ref.read(reflectionServiceProvider).appendEntry(
            threadId: widget.threadId,
            body: body,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry added')),
        );
      }
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
    return ReflectionComposer(
      showTitle: false,
      submitLabel: 'Add entry',
      busy: _busy,
      onSubmit: _append,
    );
  }
}
