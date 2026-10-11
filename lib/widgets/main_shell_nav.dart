import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/responsive_layout.dart';
import '../core/routing/shell_navigation.dart';
import '../models/saint_video.dart';

/// Compact bottom nav: Home ↔ Saints (phone / PWA).
class MainShellNav extends StatelessWidget {
  const MainShellNav({
    super.key,
    required this.selectedIndex,
    /// Show Home/Saints tabs even on wide layouts (Saints has no sidebar).
    this.alwaysShow = false,
  });

  final int selectedIndex;
  final bool alwaysShow;

  @override
  Widget build(BuildContext context) {
    if (!alwaysShow && !isCompactWidth(context)) return const SizedBox.shrink();

    return NavigationBar(
      selectedIndex: selectedIndex.clamp(0, 1),
      onDestinationSelected: (index) {
        if (index == selectedIndex) return;
        if (index == 0) {
          goToAppHome(context);
        } else {
          context.go(SaintEntry.listPath);
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome),
          label: 'Saints',
        ),
      ],
    );
  }
}
