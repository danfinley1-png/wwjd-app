import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/org_calendar_event.dart';
import '../models/org_calendar_schedule.dart';
import '../providers/admin_providers.dart';
import '../widgets/org_calendar_views.dart';
import '../../widgets/group_brand_mark.dart';

class OrgCalendarAdminScreen extends ConsumerStatefulWidget {
  const OrgCalendarAdminScreen({
    super.key,
    required this.orgId,
    required this.organizationName,
  });

  final String orgId;
  final String organizationName;

  @override
  ConsumerState<OrgCalendarAdminScreen> createState() =>
      _OrgCalendarAdminScreenState();
}

class _RowDraft {
  _RowDraft({
    required this.id,
    required String title,
    required String whenText,
    required String location,
    required String notes,
    this.startAt,
    this.endAt,
    this.allDay,
  })  : title = TextEditingController(text: title),
        whenText = TextEditingController(text: whenText),
        location = TextEditingController(text: location),
        notes = TextEditingController(text: notes);

  factory _RowDraft.fromRow(OrgScheduleRow row) {
    return _RowDraft(
      id: row.id,
      title: row.title,
      whenText: row.whenText.isNotEmpty ? row.whenText : row.displayWhen,
      location: row.location,
      notes: row.notes,
      startAt: row.startAt,
      endAt: row.endAt,
      allDay: row.allDay,
    );
  }

  factory _RowDraft.empty() {
    return _RowDraft(
      id: const Uuid().v4(),
      title: '',
      whenText: '',
      location: '',
      notes: '',
    );
  }

  final String id;
  final TextEditingController title;
  final TextEditingController whenText;
  final TextEditingController location;
  final TextEditingController notes;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool? allDay;

  OrgScheduleRow toRow(int order) {
    return OrgScheduleRow(
      id: id,
      title: title.text,
      whenText: whenText.text,
      location: location.text,
      notes: notes.text,
      sortOrder: order,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
    );
  }

  void dispose() {
    title.dispose();
    whenText.dispose();
    location.dispose();
    notes.dispose();
  }
}

class _OrgCalendarAdminScreenState
    extends ConsumerState<OrgCalendarAdminScreen> {
  final List<_RowDraft> _rows = [];
  OrgCalendarVisibility _visibility = OrgCalendarVisibility.organization;
  final Set<String> _groupIds = {};
  String? _createdByUid;
  DateTime? _createdAt;
  bool _loaded = false;
  bool _dirty = false;
  bool _importedFromEvents = false;
  bool _saving = false;
  String? _loadedFingerprint;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  String _fingerprint(OrgCalendarSchedule schedule) {
    return '${schedule.persisted}|${schedule.updatedAt}|${schedule.rows.length}|${schedule.visibility.firestoreValue}';
  }

  void _applySchedule(OrgCalendarSchedule schedule) {
    for (final row in _rows) {
      row.dispose();
    }
    _rows
      ..clear()
      ..addAll(schedule.rows.map(_RowDraft.fromRow));
    if (_rows.isEmpty) {
      _rows.add(_RowDraft.empty());
    }
    _visibility = schedule.visibility;
    _groupIds
      ..clear()
      ..addAll(schedule.groupIds);
    _createdByUid = schedule.createdByUid;
    _createdAt = schedule.createdAt;
    _importedFromEvents = schedule.importedFromEvents;
    _loaded = true;
    _dirty = false;
    _loadedFingerprint = _fingerprint(schedule);
  }

  void _addRow() {
    if (_rows.length >= OrgCalendarSchedule.maxRows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This template allows up to ${OrgCalendarSchedule.maxRows} rows.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _rows.add(_RowDraft.empty());
      _dirty = true;
    });
  }

  void _deleteRow(int index) {
    setState(() {
      _rows.removeAt(index).dispose();
      _dirty = true;
      if (_rows.isEmpty) {
        _rows.add(_RowDraft.empty());
      }
    });
  }

  OrgCalendarSchedule _draftSchedule() {
    return OrgCalendarSchedule(
      id: OrgCalendarSchedule.defaultDocId,
      organizationId: widget.orgId,
      visibility: _visibility,
      groupIds: _groupIds.toList(),
      rows: [
        for (var i = 0; i < _rows.length; i++) _rows[i].toRow(i),
      ],
      createdByUid: _createdByUid ?? '',
      createdAt: _createdAt ?? DateTime.now(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(orgCalendarServiceProvider).saveSchedule(_draftSchedule());
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _importedFromEvents = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('School schedule saved.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(isOrganizationAdminProvider(widget.orgId));
    final membership =
        ref.watch(organizationMembershipProvider(widget.orgId)).valueOrNull;
    final groupKey = (membership?.groupIds ?? const <String>[])
        .toSet()
        .toList()
      ..sort();
    final scheduleAsync = canManage
        ? ref.watch(orgCalendarScheduleAdminProvider(widget.orgId))
        : ref.watch(
            memberOrgCalendarScheduleProvider(
              OrgMemberCalendarKey(
                orgId: widget.orgId,
                groupKey: groupKey.join(','),
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GroupBrandMark(
              groupName: widget.organizationName,
              logoUrl: ref
                  .watch(organizationProvider(widget.orgId))
                  .valueOrNull
                  ?.resolvedLogoUrl,
              orgId: widget.orgId,
              size: 32,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('School / Organization Calendar'),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (canManage)
            TextButton(
              onPressed: _saving || !_loaded ? null : _save,
              child: Text(
                _saving ? 'Saving…' : 'Save',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load the schedule: $e'),
          ),
        ),
        data: (schedule) {
          if (!canManage) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(
                  children: [
                    GroupBrandMark(
                      groupName: widget.organizationName,
                      logoUrl: ref
                          .watch(organizationProvider(widget.orgId))
                          .valueOrNull
                          ?.resolvedLogoUrl,
                      orgId: widget.orgId,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.organizationName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const OrgCalendarPrivacyBanner(),
                const SizedBox(height: 16),
                OrgScheduleReadOnlyList(rows: schedule.completeRows),
              ],
            );
          }

          if (!_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_loaded) {
                setState(() => _applySchedule(schedule));
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          final fingerprint = _fingerprint(schedule);
          if (!_dirty && fingerprint != _loadedFingerprint) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_dirty) {
                setState(() => _applySchedule(schedule));
              }
            });
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              Row(
                children: [
                  GroupBrandMark(
                    groupName: widget.organizationName,
                    logoUrl: ref
                        .watch(organizationProvider(widget.orgId))
                        .valueOrNull
                        ?.resolvedLogoUrl,
                    orgId: widget.orgId,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.organizationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const OrgCalendarPrivacyBanner(),
              if (_importedFromEvents) ...[
                const SizedBox(height: 10),
                Text(
                  'Rows below were imported from earlier dated events. '
                  'Freeform When is the main field — Save to share this template.',
                  style: TextStyle(color: Colors.grey.shade800, height: 1.45),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Who can see this schedule',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Entire organization'),
                    selected: _visibility == OrgCalendarVisibility.organization,
                    onSelected: (_) => setState(() {
                      _visibility = OrgCalendarVisibility.organization;
                      _dirty = true;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Selected groups'),
                    selected: _visibility == OrgCalendarVisibility.groups,
                    onSelected: (_) => setState(() {
                      _visibility = OrgCalendarVisibility.groups;
                      _dirty = true;
                    }),
                  ),
                ],
              ),
              if (_visibility == OrgCalendarVisibility.groups) ...[
                const SizedBox(height: 12),
                _GroupChips(
                  orgId: widget.orgId,
                  selected: _groupIds,
                  onChanged: (id, selected) {
                    setState(() {
                      if (selected) {
                        _groupIds.add(id);
                      } else {
                        _groupIds.remove(id);
                      }
                      _dirty = true;
                    });
                  },
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Schedule template',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add a row for each recurring activity. When is freeform — '
                'for example “Tuesdays during lunch periods” or “Weekdays 7:20 AM”.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.45),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _rows.length; i++)
                _ScheduleRowEditor(
                  index: i,
                  draft: _rows[i],
                  onChanged: _markDirty,
                  onDelete: () => _deleteRow(i),
                ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add a row'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save schedule'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupChips extends ConsumerWidget {
  const _GroupChips({
    required this.orgId,
    required this.selected,
    required this.onChanged,
  });

  final String orgId;
  final Set<String> selected;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(organizationGroupsProvider(orgId));
    return groupsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Text('Could not load groups: $e'),
      data: (groups) {
        if (groups.isEmpty) {
          return Text(
            'This organization has no groups yet. Share with the entire organization, or add a group first.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.45),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final group in groups)
              FilterChip(
                label: Text(group.name),
                selected: selected.contains(group.id),
                onSelected: (value) => onChanged(group.id, value),
              ),
          ],
        );
      },
    );
  }
}

class _ScheduleRowEditor extends StatelessWidget {
  const _ScheduleRowEditor({
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final _RowDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Row ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: Colors.red.shade800,
                  ),
                ),
              ],
            ),
            TextField(
              controller: draft.title,
              onChanged: (_) => onChanged(),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title / activity',
                hintText: 'Chapel, lunch rosary, practice…',
                border: OutlineInputBorder(),
              ),
              maxLength: OrgScheduleRow.titleMax,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.whenText,
              onChanged: (_) => onChanged(),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'When',
                hintText: 'Tuesdays during lunch periods',
                border: OutlineInputBorder(),
              ),
              maxLength: OrgScheduleRow.whenMax,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.location,
              onChanged: (_) => onChanged(),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'Chapel, gym, room 12…',
                border: OutlineInputBorder(),
              ),
              maxLength: OrgScheduleRow.locationMax,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.notes,
              onChanged: (_) => onChanged(),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              maxLength: OrgScheduleRow.notesMax,
            ),
          ],
        ),
      ),
    );
  }
}
