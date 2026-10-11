import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../models/saint_video.dart';

class WwjdWatchSaintsLink extends StatelessWidget {
  const WwjdWatchSaintsLink({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go(SaintEntry.listPath),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryMaroon.withValues(alpha: 0.85),
      ),
      child: const Text('Watch another saint'),
    );
  }
}
