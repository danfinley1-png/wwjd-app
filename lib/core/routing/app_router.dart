import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../../screens/home_screen.dart';
import '../../screens/shared_reflection_screen.dart';

GoRouter createAppRouter(Ref ref) {
  final homeRefreshKey = ref.watch(homeRefreshKeyProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomeScreen(key: ValueKey('home-$homeRefreshKey')),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => HomeScreen(key: ValueKey('home-$homeRefreshKey')),
      ),
      GoRoute(
        path: '/s/:id',
        builder: (context, state) => SharedReflectionScreen(
          shareId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/share/:id',
        builder: (context, state) => SharedReflectionScreen(
          shareId: state.pathParameters['id']!,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.error?.toString() ?? 'Unknown route'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
