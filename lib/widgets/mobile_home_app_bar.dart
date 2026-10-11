import 'package:flutter/material.dart';

import '../core/mobile_touch.dart';
import 'wwjd_brand_title.dart';

/// Taller, touch-friendly app bar for phone / mobile web (drawer layout).
class MobileHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MobileHomeAppBar({
    super.key,
    required this.onOpenMenu,
    required this.onSignOut,
  });

  final VoidCallback onOpenMenu;
  final VoidCallback onSignOut;

  static const double toolbarHeight = 72;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: toolbarHeight,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Menu',
        onPressed: onOpenMenu,
        style: mobileIconButtonStyle(context),
      ),
      title: const WwjdBrandTitle(),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ).merge(mobileTextButtonStyle(context)),
          ),
        ),
      ],
    );
  }
}
