import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/saint_video.dart';
import '../providers/admin_providers.dart';
import 'edit_saint_screen.dart';

/// Overall Admin catalog of saint video series (draft and published).
class AdminSaintsScreen extends ConsumerWidget {
  const AdminSaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
    if (!isSuperAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saints videos')),
        body: const Center(child: Text('Overall Admin access required.')),
      );
    }

    final saintsAsync = ref.watch(adminSaintsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saints videos'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('New saint'),
      ),
      body: saintsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load saints.\n$e')),
        data: (saints) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              Text(
                'Each saint is eight short clips stored in Firebase Storage. '
                'The app only reads Firestore metadata — video files are never bundled.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.45),
              ),
              const SizedBox(height: 16),
              if (saints.isEmpty)
                const Text('No saint entries yet. Create one to begin.')
              else
                for (final saint in saints)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(saint.name),
                      subtitle: Text(
                        [
                          saint.status.label,
                          if (saint.feastDay.trim().isNotEmpty) saint.feastDay,
                          '${saint.playableSegments.length}/${SaintSegment.count} clips',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditSaintScreen(saintId: saint.id),
                          ),
                        );
                      },
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NewSaintDialog(),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditSaintScreen(createName: name.trim()),
      ),
    );
  }
}

class _NewSaintDialog extends StatefulWidget {
  const _NewSaintDialog();

  @override
  State<_NewSaintDialog> createState() => _NewSaintDialogState();
}

class _NewSaintDialogState extends State<_NewSaintDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New saint'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. St. Francis of Assisi',
        ),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
