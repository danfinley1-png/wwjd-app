import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../core/app_colors.dart';
import '../core/config.dart';
import '../core/responsive_layout.dart';
import 'linked_markdown_body.dart';

/// Welcome copy on Home when there is no chat thread yet (not a chat message).
class HomeWelcomeSection extends StatelessWidget {
  const HomeWelcomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final horizontal = responsiveHorizontalPadding(context);

    return Padding(
      padding: horizontal.copyWith(top: 8, bottom: 16),
      child: LinkedMarkdownBody(
        data: AppConfig.homeWelcomeMarkdown.trim(),
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            fontSize: isCompactWidth(context) ? 15 : 16,
            height: 1.6,
            color: AppColors.textPrimary,
          ),
          strong: TextStyle(
            fontSize: isCompactWidth(context) ? 18 : 20,
            fontWeight: FontWeight.bold,
            height: 1.35,
            color: AppColors.primaryMaroon,
          ),
          blockSpacing: 14,
        ),
      ),
    );
  }
}
