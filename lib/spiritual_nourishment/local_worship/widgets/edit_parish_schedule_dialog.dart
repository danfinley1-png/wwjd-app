import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/responsive_layout.dart';
import '../../../core/user_text_input.dart';
import '../models/parish.dart';
import '../models/parish_schedule.dart';

class ScheduleEditResult {
  const ScheduleEditResult.save(this.schedule) : revert = false;
  const ScheduleEditResult.revert()
      : schedule = null,
        revert = true;

  final ParishSchedule? schedule;
  final bool revert;
}

Future<ScheduleEditResult?> showEditParishScheduleDialog(
  BuildContext context, {
  required Parish parish,
  bool hasOverride = false,
}) {
  return showDialog<ScheduleEditResult>(
    context: context,
    builder: (dialogContext) => EditParishScheduleDialog(
      parish: parish,
      hasOverride: hasOverride,
    ),
  );
}

class EditParishScheduleDialog extends StatefulWidget {
  const EditParishScheduleDialog({
    super.key,
    required this.parish,
    this.hasOverride = false,
  });

  final Parish parish;
  final bool hasOverride;

  @override
  State<EditParishScheduleDialog> createState() =>
      _EditParishScheduleDialogState();
}

class _EditParishScheduleDialogState extends State<EditParishScheduleDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final row in widget.parish.schedule.rows)
        row.label: TextEditingController(
          text: row.value == ParishSchedule.notListed ? '' : row.value,
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ParishSchedule _fromFields() {
    String valueFor(String label) {
      final text = _controllers[label]?.text.trim() ?? '';
      return text.isEmpty ? ParishSchedule.notListed : text;
    }

    return ParishSchedule(
      massTimes: valueFor('Mass times'),
      communionService: valueFor('Communion service'),
      confession: valueFor('Confession'),
      holyDays: valueFor('Holy Days'),
      eucharisticAdoration: valueFor('Eucharistic Adoration'),
      openForPrayer: valueFor('Open for prayer / church open hours'),
      perpetualAdoration: valueFor('Perpetual adoration'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = responsiveDialogMaxWidth(context, max: 520);

    return AlertDialog(
      title: Text('Edit schedule for ${widget.parish.name}'),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Times from MassTimes.org can be incomplete. Enter what the parish publishes, then confirm with the parish.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              for (final row in widget.parish.schedule.rows) ...[
                UserTextField(
                  controller: _controllers[row.label],
                  minLines: 2,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: row.label,
                    hintText: ParishSchedule.notListed,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.hasOverride)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const ScheduleEditResult.revert()),
            child: const Text('Use MassTimes listing'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryMaroon),
          onPressed: () =>
              Navigator.pop(context, ScheduleEditResult.save(_fromFields())),
          child: const Text('Save schedule'),
        ),
      ],
    );
  }
}
