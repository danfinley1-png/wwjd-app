import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/config.dart';
import 'core/app_colors.dart';
import 'core/routing/app_router.dart';
import 'firebase_options.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  runApp(
    const ProviderScope(
      child: WWJDApp(),
    ),
  );
}

class WWJDApp extends ConsumerWidget {
  const WWJDApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: router,
    );
  }

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

final _routerProvider = Provider<GoRouter>((ref) => createAppRouter(ref));
