import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/config.dart';
import '../core/responsive_layout.dart';

/// Starter prompts for empty Home chat — full-length WWJD responses.
class WwjdHomeDecisionChips extends StatelessWidget {
  const WwjdHomeDecisionChips({
    super.key,
    required this.onSelectPrompt,
  });

  final ValueChanged<String> onSelectPrompt;

  @override
  Widget build(BuildContext context) {
    final horizontal = responsiveHorizontalPadding(context);

    return Padding(
      padding: horizontal.copyWith(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final prompt in AppConfig.homeDecisionChips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ActionChip(
                label: Text(
                  prompt,
                  style: const TextStyle(height: 1.35),
                ),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: AppColors.primaryMaroon.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onPressed: () => onSelectPrompt(prompt),
              ),
            ),
        ],
      ),
    );
  }
}
