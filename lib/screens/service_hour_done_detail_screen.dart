import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../admin/models/service_hours.dart';
import '../admin/providers/admin_providers.dart';
import '../core/app_colors.dart';
import '../core/providers/reflection_providers.dart';
import 'reflection_detail_screen.dart';

/// Member-facing hour entry. Work note only — never the private reflection body.
class ServiceHourDoneDetailScreen extends ConsumerWidget {
  const ServiceHourDoneDetailScreen({
    super.key,
    required this.entry,
  });

  final ServiceHourEntry entry;

  static final _dateFormat = DateFormat('EEEE, MMMM d, yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = ref.watch(memberAssignedServiceProjectsProvider).valueOrNull;
    ServiceProject? fromAssigned;
    if (assigned != null) {
      for (final project in assigned) {
        if (project.id == entry.projectId) {
          fromAssigned = project;
          break;
        }
      }
    }
    final projectAsync = fromAssigned != null
        ? AsyncValue.data(fromAssigned)
        : ref.watch(serviceProjectByIdProvider(entry.projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service hours'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          projectAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (_, __) => const Text(
              'Service hours',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryMaroon,
              ),
            ),
            data: (project) => Text(
              project?.title.trim().isNotEmpty == true
                  ? project!.title
                  : 'Service hours',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryMaroon,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          _MetaRow(label: 'Date', value: _dateFormat.format(entry.date)),
          _MetaRow(
            label: 'Hours',
            value: ServiceHourEntry.formatHours(entry.hours),
          ),
          _MetaRow(label: 'Status', value: entry.statusDisplayLabel),
          if (entry.note.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Work note',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.note.trim(),
              style: const TextStyle(fontSize: 16, height: 1.45),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _openReflection(context, ref),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Open My Reflections'),
          ),
        ],
      ),
    );
  }

  Future<void> _openReflection(BuildContext context, WidgetRef ref) async {
    try {
      var threadId = entry.reflectionId?.trim();
      if (threadId == null || threadId.isEmpty) {
        final thread = await ref
            .read(reflectionServiceProvider)
            .findThreadForServiceEntry(entry.id);
        threadId = thread?.id;
      }
      if (!context.mounted) return;
      if (threadId == null || threadId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No linked reflection yet for these hours.'),
          ),
        );
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ReflectionDetailScreen(threadId: threadId!),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open reflection: $e')),
      );
    }
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
