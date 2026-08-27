import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/mobile_touch.dart';

/// Taller, touch-friendly app bar for phone / mobile web (drawer layout).
class MobileHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MobileHomeAppBar({
    super.key,
    required this.onOpenMenu,
    required this.onSignOut,
  });

  final VoidCallback onOpenMenu;
  final VoidCallback onSignOut;

  /// Room for logo, full title, and readable tagline on iPhone.
  static const double toolbarHeight = 122;

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
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/wwjd_header.jpg',
              height: 54,
              width: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.church,
                size: 54,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppConfig.mobileDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppConfig.tagline,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.28,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
