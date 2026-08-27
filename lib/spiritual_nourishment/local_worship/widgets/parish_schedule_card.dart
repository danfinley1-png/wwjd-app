import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_colors.dart';
import '../../../core/external_link.dart';
import '../models/parish.dart';
import '../models/parish_schedule.dart';
import '../services/mass_times_links.dart';

class ParishScheduleCard extends StatelessWidget {
  const ParishScheduleCard({
    super.key,
    required this.parish,
    this.onChooseAsMyParish,
    this.onEditSchedule,
    this.showChooseAction = true,
    this.showMassTimesLink = true,
    this.badgeLabel,
  });

  final Parish parish;
  final VoidCallback? onChooseAsMyParish;
  final VoidCallback? onEditSchedule;
  final bool showChooseAction;
  final bool showMassTimesLink;
  final String? badgeLabel;

  static const disclaimer =
      'Schedules change. Please confirm times with the parish before you go.';

  @override
  Widget build(BuildContext context) {
    final massTimesUri = MassTimesLinks.parishOnMap(
      ParishLinkTarget(
        name: parish.name,
        address: parish.address,
        latitude: parish.latitude,
        longitude: parish.longitude,
      ),
    );

    return Card(
      elevation: parish.isMyParish ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: parish.isMyParish
            ? const BorderSide(color: AppColors.gold, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (badgeLabel != null)
                  _Badge(label: badgeLabel!, icon: Icons.school_outlined)
                else ...[
                  if (parish.isMyParish)
                    const _Badge(label: 'My Parish', icon: Icons.favorite),
                  if (parish.isPerpetualAdorationChapel)
                    const _Badge(
                      label: 'Closest perpetual adoration',
                      icon: Icons.wb_sunny_outlined,
                    ),
                  if (!parish.isMyParish && !parish.isPerpetualAdorationChapel)
                    const _Badge(label: 'Nearby parish', icon: Icons.place_outlined),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              parish.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (parish.address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(parish.address, style: const TextStyle(height: 1.4)),
            ],
            if (parish.distanceLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'About ${parish.distanceLabel}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryMaroon,
                ),
              ),
            ],
            if (parish.hasWebsite) ...[
              const SizedBox(height: 8),
              _LinkLine(
                icon: Icons.language,
                label: 'Parish website',
                onTap: () => launchExternalLink(context, parish.website!),
              ),
            ],
            if (parish.hasPhone) ...[
              const SizedBox(height: 4),
              _LinkLine(
                icon: Icons.phone_outlined,
                label: parish.phone!,
                onTap: () => _launchTel(context, parish.phone!),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Worship times',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (onEditSchedule != null)
                  TextButton.icon(
                    onPressed: onEditSchedule,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit schedule'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final row in parish.schedule.rows) ...[
              _ScheduleLine(rowLabel: row.label, value: row.value),
              const SizedBox(height: 10),
            ],
            if (showMassTimesLink)
              TextButton.icon(
                onPressed: () =>
                    launchExternalLink(context, massTimesUri.toString()),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('View on MassTimes.org'),
              ),
            if (showChooseAction && onChooseAsMyParish != null && !parish.isMyParish)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onChooseAsMyParish,
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Set as My Parish'),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              disclaimer,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchTel(BuildContext context, String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Phone: $phone')),
        );
      }
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: AppColors.primaryMaroon),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.parchmentDark,
      side: BorderSide.none,
    );
  }
}

class _LinkLine extends StatelessWidget {
  const _LinkLine({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryMaroon),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.primaryMaroon,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleLine extends StatelessWidget {
  const _ScheduleLine({required this.rowLabel, required this.value});

  final String rowLabel;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rowLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            height: 1.45,
            color: value == ParishSchedule.notListed
                ? Colors.grey.shade600
                : AppColors.textSecondary,
            fontStyle:
                value == ParishSchedule.notListed ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}
