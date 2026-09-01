import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../admin/models/service_hours.dart';
import '../admin/providers/admin_providers.dart';
import '../core/app_colors.dart';
import '../core/providers/reflection_providers.dart';
import '../core/user_text_input.dart';

/// Create or edit one of the signed-in member's hour entries.
class LogServiceHoursScreen extends ConsumerStatefulWidget {
  const LogServiceHoursScreen({
    super.key,
    required this.project,
    this.existing,
  });

  final ServiceProject project;
  final ServiceHourEntry? existing;

  @override
  ConsumerState<LogServiceHoursScreen> createState() =>
      _LogServiceHoursScreenState();
}

class _LogServiceHoursScreenState extends ConsumerState<LogServiceHoursScreen> {
  late DateTime _date;
  late double _hours;
  final _note = TextEditingController();
  final _reflection = TextEditingController();
  bool _addReflection = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final range = ServiceHourEntryValidation.selectableDateRange(widget.project);
    if (existing != null) {
      _date = DateTime(
        existing.date.year,
        existing.date.month,
        existing.date.day,
      );
      _hours = ServiceHourEntry.snapHours(existing.hours);
      _note.text = existing.note;
    } else if (range != null) {
      _date = range.last;
      _hours = 1;
    } else {
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
      _hours = 1;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _reflection.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final range = ServiceHourEntryValidation.selectableDateRange(widget.project);
    if (range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hours can be logged only on dates inside the project window.',
          ),
        ),
      );
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(range.first)
          ? range.first
          : (_date.isAfter(range.last) ? range.last : _date),
      firstDate: range.first,
      lastDate: range.last,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final range = ServiceHourEntryValidation.selectableDateRange(widget.project);
    if (range == null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This project is not open for hour logging yet.',
          ),
        ),
      );
      return;
    }

    final error = ServiceHourEntryValidation.validate(
      project: widget.project,
      date: _date,
      hours: _hours,
      note: _note.text,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    final hoursService = ref.read(serviceHourEntryServiceProvider);
    try {
      String entryId;
      if (_isEditing) {
        await hoursService.updateEntry(
          project: widget.project,
          existing: widget.existing!,
          date: _date,
          hours: _hours,
          note: _note.text,
        );
        entryId = widget.existing!.id;
      } else {
        entryId = await hoursService.createEntry(
          project: widget.project,
          date: _date,
          hours: _hours,
          note: _note.text,
        );
      }

      var reflectionSaved = false;
      final reflectionBody = _reflection.text.trim();
      if (_addReflection && reflectionBody.isNotEmpty) {
        try {
          final thread =
              await ref.read(reflectionServiceProvider).upsertServiceReflection(
                    projectId: widget.project.id,
                    entryId: entryId,
                    projectTitle: widget.project.title,
                    body: reflectionBody,
                  );
          if (widget.existing == null || !widget.existing!.hasReflection) {
            await hoursService.attachReflectionId(
              entryId: entryId,
              reflectionId: thread.id,
            );
          }
          reflectionSaved = true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Hours saved. The private reflection could not be saved: $e',
                ),
              ),
            );
          }
          if (mounted) Navigator.pop(context, true);
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reflectionSaved
                ? 'Hours saved. The reflection is in My Reflections and stays private.'
                : widget.project.requiresApproval
                    ? 'Hours saved as pending. They count after approval.'
                    : 'Hours logged.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save hours: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final location = project.location.trim();
    final range = ServiceHourEntryValidation.selectableDateRange(project);
    final canLog = range != null || _isEditing;
    final dateFmt = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit hours' : 'Log hours'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            project.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              location,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Mode: ${project.modeDisplayLabel}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (!canLog) ...[
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Hours can be logged once the project window has started. '
                  'The dates on this project are listed so the group can plan.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of service'),
            subtitle: Text(dateFmt.format(_date)),
            trailing: const Icon(Icons.calendar_today_outlined),
            enabled: canLog,
            onTap: canLog ? _pickDate : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Hours',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _HoursStepper(
            hours: _hours,
            enabled: canLog && !_saving,
            onChanged: (value) => setState(() => _hours = value),
          ),
          const SizedBox(height: 20),
          UserTextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Work note (optional)',
              hintText:
                  'What was done — visible later to approvers, not a journal.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _addReflection,
            onChanged: _saving
                ? null
                : (value) => setState(() => _addReflection = value ?? false),
            title: const Text('Add a private reflection'),
            subtitle: const Text(
              'Saved in My Reflections. It stays private and is never stored '
              'on the hour record.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_addReflection) ...[
            const SizedBox(height: 8),
            UserTextField(
              controller: _reflection,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Private reflection',
                hintText: 'Write freely — only you will see this.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canLog && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Save changes' : 'Save hours'),
          ),
        ],
      ),
    );
  }
}

class _HoursStepper extends StatelessWidget {
  const _HoursStepper({
    required this.hours,
    required this.onChanged,
    required this.enabled,
  });

  final double hours;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: enabled && hours > ServiceHourEntry.hoursMin
              ? () => onChanged(
                    ServiceHourEntry.snapHours(
                      hours - ServiceHourEntry.hoursMin,
                    ),
                  )
              : null,
          tooltip: 'Subtract 15 minutes',
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: Text(
            '${ServiceHourEntry.formatHours(hours)} hrs',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: enabled && hours < ServiceHourEntry.hoursMax
              ? () => onChanged(
                    ServiceHourEntry.snapHours(
                      hours + ServiceHourEntry.hoursMin,
                    ),
                  )
              : null,
          tooltip: 'Add 15 minutes',
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
