import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../models/saint_video.dart';
import '../../widgets/saints_sequence_player.dart';

/// Create or edit a saint entry, write/paste script, upload clips, preview, publish.
class EditSaintScreen extends ConsumerStatefulWidget {
  const EditSaintScreen({
    super.key,
    this.saintId,
    this.createName,
  }) : assert(saintId != null || createName != null,
            'Provide saintId (edit) or createName (create).');

  final String? saintId;
  final String? createName;

  @override
  ConsumerState<EditSaintScreen> createState() => _EditSaintScreenState();
}

class _EditSaintScreenState extends ConsumerState<EditSaintScreen> {
  late String _resolvedId;
  SaintEntry? _entry;
  bool _creating = false;
  bool _loaded = false;
  String? _loadError;

  final _nameController = TextEditingController();
  final _feastController = TextEditingController();
  final _summaryController = TextEditingController();
  final _scriptPasteController = TextEditingController();

  List<TextEditingController> _titleControllers = [];
  List<TextEditingController> _scriptControllers = [];
  List<TextEditingController> _captionControllers = [];

  bool _saving = false;
  bool _publishing = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _titleControllers = List.generate(
        SaintSegment.count, (i) => TextEditingController());
    _scriptControllers = List.generate(
        SaintSegment.count, (i) => TextEditingController());
    _captionControllers = List.generate(
        SaintSegment.count, (i) => TextEditingController());

    if (widget.saintId != null) {
      _resolvedId = widget.saintId!;
      _loadExisting();
    } else {
      _creating = true;
      _resolvedId = '';
      _nameController.text = widget.createName ?? '';
      for (var i = 0; i < SaintSegment.count; i++) {
        _titleControllers[i].text = 'Part ${i + 1}';
      }
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feastController.dispose();
    _summaryController.dispose();
    _scriptPasteController.dispose();
    for (final c in [..._titleControllers, ..._scriptControllers, ..._captionControllers]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final service = ref.read(saintsServiceProvider);
      final entry = await service.getById(_resolvedId);
      if (!mounted) return;
      if (entry == null) {
        setState(() {
          _loadError = 'Saint entry not found.';
          _loaded = true;
        });
        return;
      }
      _applyEntry(entry);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loaded = true;
      });
    }
  }

  void _applyEntry(SaintEntry entry) {
    _entry = entry;
    _nameController.text = entry.name;
    _feastController.text = entry.feastDay;
    _summaryController.text = entry.summary;
    final segs = [...entry.segments]..sort((a, b) => a.order.compareTo(b.order));
    for (var i = 0; i < segs.length && i < SaintSegment.count; i++) {
      _titleControllers[i].text = segs[i].title;
      _scriptControllers[i].text = segs[i].script;
      _captionControllers[i].text = segs[i].caption;
    }
    setState(() => _loaded = true);
  }

  void _applyPastedScript() {
    final raw = _scriptPasteController.text.trim();
    if (raw.isEmpty) return;
    final parts = SaintEntry.splitScriptPaste(raw);
    for (var i = 0; i < parts.length && i < SaintSegment.count; i++) {
      _scriptControllers[i].text = parts[i];
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Applied ${parts.length} script section${parts.length == 1 ? '' : 's'}.')),
    );
    _scriptPasteController.clear();
  }

  SaintEntry _buildEntry() {
    final id = _creating
        ? SaintEntry.slugify(_nameController.text)
        : _resolvedId;
    final segments = <SaintSegment>[];
    final existing = _entry?.segments ?? SaintEntry.emptySegments();
    final existingByOrder = {for (final s in existing) s.order: s};
    for (var i = 0; i < SaintSegment.count; i++) {
      final order = i + 1;
      final old = existingByOrder[order];
      segments.add(SaintSegment(
        order: order,
        title: _titleControllers[i].text.trim().isEmpty
            ? 'Part $order'
            : _titleControllers[i].text.trim(),
        script: _scriptControllers[i].text.trim(),
        videoUrl: old?.videoUrl ?? '',
        durationSec: old?.durationSec ?? SaintSegment.defaultDurationSec,
        caption: _captionControllers[i].text.trim(),
      ));
    }
    return SaintEntry(
      id: id,
      name: _nameController.text.trim(),
      feastDay: _feastController.text.trim(),
      summary: _summaryController.text.trim(),
      segments: segments,
      status: _entry?.status ?? SaintPublishStatus.draft,
      publishedAt: _entry?.publishedAt,
      createdAt: _entry?.createdAt,
      updatedAt: _entry?.updatedAt,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _actionError = null;
    });
    try {
      final service = ref.read(saintsServiceProvider);
      if (_creating) {
        final entry = _buildEntry();
        _resolvedId = entry.id;
        await service.createDraft(
          name: entry.name,
          feastDay: entry.feastDay,
          summary: entry.summary,
        );
        // Save full segment metadata (titles/scripts/captions)
        await service.saveMetadata(entry.copyWith(status: SaintPublishStatus.draft));
        setState(() => _creating = false);
        _entry = entry;
      } else {
        final entry = _buildEntry();
        await service.saveMetadata(entry);
        _entry = entry;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadClip(int index) async {
    if (_creating) {
      setState(() => _actionError = 'Save the entry first, then upload clips.');
      return;
    }
    if (_entry == null) return;
    setState(() => _actionError = null);
    try {
      final service = ref.read(saintsServiceProvider);
      final bytes = await service.pickMp4Bytes();
      if (bytes == null) return;
      if (!mounted) return;
      setState(() => _saving = true);
      final updated = await service.uploadSegmentMp4(
        entry: _entry!,
        order: index + 1,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _entry = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Part ${index + 1} uploaded.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = e.toString();
        _saving = false;
      });
    }
  }

  Future<void> _togglePublish() async {
    if (_publishing || _entry == null) return;
    final publish = _entry!.status == SaintPublishStatus.draft;
    if (publish && !_entry!.canPublish) {
      setState(() =>
          _actionError = 'Upload all ${SaintSegment.count} clips before publishing.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(publish ? 'Publish' : 'Unpublish'),
        content: Text(
          publish
              ? 'Make this saint series visible to all signed-in members?'
              : 'Move this saint series back to draft (hidden from members)?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(publish ? 'Publish' : 'Unpublish')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _publishing = true;
      _actionError = null;
    });
    try {
      final service = ref.read(saintsServiceProvider);
      if (publish) {
        await service.publish(_entry!);
        _entry = _entry!.copyWith(status: SaintPublishStatus.published);
      } else {
        await service.unpublish(_entry!);
        _entry = _entry!.copyWith(status: SaintPublishStatus.draft);
      }
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.toString());
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saints video')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saints video')),
        body: Center(child: Text(_loadError!)),
      );
    }

    final isPublished = _entry?.status == SaintPublishStatus.published;

    return Scaffold(
      appBar: AppBar(
        title: Text(_creating ? 'New saint' : (_entry?.name ?? 'Edit saint')),
        centerTitle: true,
        actions: [
          if (!_creating && _entry != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _publishing ? null : _togglePublish,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isPublished ? Colors.grey.shade700 : const Color(0xFF2E7D32),
                ),
                child: Text(isPublished ? 'Unpublish' : 'Publish'),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Metadata section
          const _SectionLabel('Saint details'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name *',
              hintText: 'e.g. St. Thérèse of Lisieux',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feastController,
            decoration: const InputDecoration(
              labelText: 'Feast day',
              hintText: 'e.g. October 1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _summaryController,
            decoration: const InputDecoration(
              labelText: 'Summary',
              hintText: 'One or two sentences about this saint.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            maxLength: SaintEntry.maxSummaryLength,
          ),
          const SizedBox(height: 20),

          // Script paste
          const _SectionLabel('Paste full 8-part script'),
          const SizedBox(height: 4),
          Text(
            'Separate parts with --- on its own line or a blank line. '
            'Only scripts are pasted; video clips are uploaded per segment below.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _scriptPasteController,
            decoration: const InputDecoration(
              labelText: 'Paste script here',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            maxLines: 6,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _applyPastedScript,
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: const Text('Apply to segments'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),

          // Per-segment editors
          const _SectionLabel('Segments (8 × ~15 s clips)'),
          const SizedBox(height: 4),
          Text(
            'Upload each .mp4 (max 12 MB). Metadata saves to Firestore; '
            'files go to Firebase Storage — nothing is bundled in the app.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < SaintSegment.count; i++)
            _SegmentEditor(
              index: i,
              segment: _entry?.segments.firstWhere(
                (s) => s.order == i + 1,
                orElse: () => SaintSegment.empty(i + 1),
              ),
              titleController: _titleControllers[i],
              scriptController: _scriptControllers[i],
              captionController: _captionControllers[i],
              onUpload: () => _uploadClip(i),
              busy: _saving,
            ),

          if (_actionError != null) ...[
            const SizedBox(height: 12),
            Text(_actionError!,
                style: TextStyle(color: Colors.red.shade800)),
          ],
          const SizedBox(height: 24),

          // Preview
          if (!_creating && _entry != null) ...[
            const Divider(),
            const SizedBox(height: 12),
            const _SectionLabel('Preview'),
            const SizedBox(height: 8),
            SaintsSequencePlayer(
              segments: _entry!.playableSegments,
              autoPlay: false,
            ),
            const SizedBox(height: 24),
          ],

          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));
  }
}

class _SegmentEditor extends StatelessWidget {
  const _SegmentEditor({
    required this.index,
    required this.segment,
    required this.titleController,
    required this.scriptController,
    required this.captionController,
    required this.onUpload,
    required this.busy,
  });

  final int index;
  final SaintSegment? segment;
  final TextEditingController titleController;
  final TextEditingController scriptController;
  final TextEditingController captionController;
  final VoidCallback onUpload;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final hasVideo = segment?.hasVideo == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Part ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (hasVideo)
                  const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : onUpload,
                  icon: Icon(
                    hasVideo ? Icons.refresh : Icons.upload_file,
                    size: 18,
                  ),
                  label: Text(hasVideo ? 'Replace clip' : 'Upload .mp4'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLength: SaintSegment.maxTitleLength,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: scriptController,
              decoration: const InputDecoration(
                labelText: 'Script',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 4,
              maxLength: SaintSegment.maxScriptLength,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: captionController,
              decoration: const InputDecoration(
                labelText: 'Caption (displayed during playback)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLength: SaintSegment.maxCaptionLength,
            ),
          ],
        ),
      ),
    );
  }
}
