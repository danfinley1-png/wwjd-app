import 'package:flutter/material.dart';

/// Centralized Catholic-inspired color palette for the WWJD app.
/// Follows the design direction in docs/ARCHITECTURE.md (maroon/gold + warm parchment tones).
/// Use these constants everywhere instead of magic 0xFF values for consistency and easy theming.
class AppColors {
  AppColors._(); // Utility class

  // Primary Catholic maroon / burgundy (header, accents, send button)
  static const Color primaryMaroon = Color(0xFF8B1E1E);

  // Warm parchment / off-white backgrounds
  static const Color parchment = Color(0xFFF8F5F0);
  static const Color parchmentDark = Color(0xFFF0EDE6); // Slightly deeper variant

  // Sidebar background (warm tan)
  static const Color sidebarBackground = Color(0xFFF0EDE6);

  // Gold accents (subtle, reverent — used for borders, icons, highlights)
  static const Color gold = Color(0xFFB8860B);
  static const Color goldLight = Color(0xFFD4AF37);

  // Chat bubbles
  static const Color userBubble = Color(0xFFE3F2FD); // Soft blue for user
  static const Color assistantBubble = Colors.white;

  // Text
  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF5C5C5C);
  static const Color textOnMaroon = Colors.white;

  // Status / utility
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFE65100);

  // Material 3 seed-friendly helpers (light theme)
  static ColorScheme get lightColorScheme => ColorScheme.fromSeed(
        seedColor: primaryMaroon,
        brightness: Brightness.light,
        surface: parchment,
        surfaceContainerHighest: parchmentDark,   // ← Fixed deprecation
      );
}
