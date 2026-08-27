import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/pastoral_insights_models.dart';
import '../../models/pastoral_theme.dart';

/// Horizontal bar for one pastoral theme in the insights dashboard.
class PastoralThemeBar extends StatelessWidget {
  const PastoralThemeBar({
    super.key,
    required this.entry,
    required this.maxCount,
  });

  final ThemeInsightCount entry;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount <= 0 ? 0.0 : entry.count / maxCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.theme.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.count} · ${entry.percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.parchmentDark,
              color: AppColors.primaryMaroon,
            ),
          ),
        ],
      ),
    );
  }
}
