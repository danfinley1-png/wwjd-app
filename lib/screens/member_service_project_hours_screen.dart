import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../admin/models/service_hours.dart';
import '../admin/providers/admin_providers.dart';
import '../core/app_colors.dart';
import '../core/providers/reflection_providers.dart';
import '../core/user_text_input.dart';
import 'log_service_hours_screen.dart';

/// The signed-in member's hour list and total for one assigned project.
class MemberServiceProjectHoursScreen extends ConsumerWidget {
  const MemberServiceProjectHoursScreen({
    super.key,
    required this.project,
  });

  final ServiceProject project;

  Future<void> _openLog(
    BuildContext context, {
    ServiceHourEntry? existing,
  }) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LogServiceHoursScreen(
          project: project,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ServiceHourEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text(
          'This removes only your hour record. A private reflection, if any, '
          'stays in My Reflections.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(serviceHourEntryServiceProvider).deleteEntry(entry);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted')),
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

  Future<void> _addReflection(
    BuildContext context,
    WidgetRef ref,
    ServiceHourEntry entry,
  ) async {
    final controller = TextEditingController();
    final String? body;
    try {
      body = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Private reflection'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This is saved in My Reflections and stays private. '
                'It is never stored on the hour record.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              UserTextField(
                controller: controller,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Your reflection',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    } finally {
      controller.dispose();
    }
    if (body == null || body.trim().isEmpty || !context.mounted) return;
    try {
      final thread =
          await ref.read(reflectionServiceProvider).upsertServiceReflection(
                projectId: project.id,
                entryId: entry.id,
                projectTitle: project.title,
                body: body,
              );
      if (!entry.hasReflection) {
        await ref.read(serviceHourEntryServiceProvider).attachReflectionId(
              entryId: entry.id,
              reflectionId: thread.id,
            );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved in My Reflections. It remains private.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the reflection: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(memberProjectHourEntriesProvider(project.id));
    final location = project.location.trim();
    final window = _windowLabel(project);
    final range = ServiceHourEntryValidation.selectableDateRange(project);
    final dateFmt = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service hours'),
        centerTitle: true,
      ),
      floatingActionButton: range == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openLog(context),
              icon: const Icon(Icons.add),
              label: const Text('Log hours'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            project.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(location, style: const TextStyle(color: AppColors.textSecondary)),
          ],
          if (window.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(window, style: const TextStyle(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 6),
          Text(
            'Mode: ${project.modeDisplayLabel}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (range == null) ...[
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Hours can be logged once the project window has started.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          entriesAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, __) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your hours could not be loaded yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(
                        memberProjectHourEntriesProvider(project.id),
                      ),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
            data: (entries) {
              final total = ServiceHourEntry.countedHours(entries);
              final pending = entries
                  .where((e) => e.status == ServiceHourEntry.statusPending)
                  .fold<double>(0, (sum, e) => sum + e.hours);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: AppColors.parchmentDark,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${ServiceHourEntry.formatHours(total)} hours',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Counts logged and approved hours only.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (pending > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${ServiceHourEntry.formatHours(pending)} pending — not counted until approved.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your entries',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (entries.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No hours logged on this project yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...entries.map(
                      (entry) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${dateFmt.format(entry.date)} · ${ServiceHourEntry.formatHours(entry.hours)} hrs',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  _StatusChip(status: entry.statusDisplayLabel),
                                ],
                              ),
                              if (entry.note.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(entry.note.trim()),
                              ],
                              if (entry.hasReflection) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  'Private reflection saved in My Reflections',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                children: [
                                  if (entry.isOwnerEditable)
                                    TextButton(
                                      onPressed: () =>
                                          _openLog(context, existing: entry),
                                      child: const Text('Edit'),
                                    ),
                                  if (entry.isOwnerEditable)
                                    TextButton(
                                      onPressed: () =>
                                          _confirmDelete(context, ref, entry),
                                      child: const Text('Delete'),
                                    ),
                                  TextButton(
                                    onPressed: () =>
                                        _addReflection(context, ref, entry),
                                    child: Text(
                                      entry.hasReflection
                                          ? 'Add another reflection'
                                          : 'Add a private reflection',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _windowLabel(ServiceProject project) {
    final start = project.startDate;
    final end = project.endDate;
    if (start == null && end == null) return '';
    final fmt = DateFormat.yMMMd();
    if (start != null && end != null) {
      return '${fmt.format(start)} – ${fmt.format(end)}';
    }
    if (start != null) return 'Starts ${fmt.format(start)}';
    return 'Through ${fmt.format(end!)}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.parchment,
    );
  }
}
