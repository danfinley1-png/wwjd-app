import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../models/org_calendar_schedule.dart';

class OrgCalendarPrivacyBanner extends StatelessWidget {
  const OrgCalendarPrivacyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.calendar_month_outlined, color: Colors.blueGrey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'School / Organization Calendar is a shared institutional schedule — '
              'not Sharing My Gifts reminders. Seeking God’s Wisdom, My Reflections, '
              'My History, and personal Gifts stay private and are never shown here.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.blueGrey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only schedule rows for members (and non-editing admins).
class OrgScheduleReadOnlyList extends StatelessWidget {
  const OrgScheduleReadOnlyList({
    super.key,
    required this.rows,
    this.emptyMessage =
        'No school or organization schedule has been shared yet.',
  });

  final List<OrgScheduleRow> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((row) => row.isComplete).toList();
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, height: 1.45),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OrgScheduleReadOnlyCard(row: visible[i]),
          ),
      ],
    );
  }
}

class OrgScheduleReadOnlyCard extends StatelessWidget {
  const OrgScheduleReadOnlyCard({
    super.key,
    required this.row,
  });

  final OrgScheduleRow row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.title.trim(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _MetaLine(icon: Icons.schedule, label: 'When', value: row.displayWhen),
            if (row.location.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              _MetaLine(
                icon: Icons.place_outlined,
                label: 'Location',
                value: row.location.trim(),
              ),
            ],
            if (row.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              _MetaLine(
                icon: Icons.notes_outlined,
                label: 'Notes',
                value: row.notes.trim(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryMaroon),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
            style: const TextStyle(height: 1.4),
          ),
        ),
      ],
    );
  }
}
