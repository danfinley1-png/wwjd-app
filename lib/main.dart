import 'package:flutter/material.dart';
import 'core/config.dart';
import 'core/app_colors.dart';
import 'screens/home_screen.dart';

/// WWJD – DI Catholic Dialog App
/// Entry point kept deliberately thin per ARCHITECTURE.md guidance.
/// All UI, state, and mocked WWJD response logic lives in lib/screens/home_screen.dart.
void main() {
  runApp(const WWJDApp());
}

class WWJDApp extends StatelessWidget {
  const WWJDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const HomeScreen(),
    );
  }

  /// Material 3 theme with warm Catholic aesthetic.
  /// Primary maroon + parchment surfaces + subtle gold accents.
  /// See AppColors for the single source of truth for palette values.
  ThemeData _buildTheme() {
    final base = AppColors.lightColorScheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.parchment,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryMaroon,
        foregroundColor: AppColors.textOnMaroon,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textOnMaroon,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: AppColors.primaryMaroon.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.primaryMaroon, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSecondary),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
    );
  }
}
