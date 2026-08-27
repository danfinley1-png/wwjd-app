import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../../screens/home_screen.dart';
import '../../screens/shared_reflection_screen.dart';
import '../../screens/gift_activity_screen.dart';
import '../../screens/pending_group_invites_screen.dart';
import '../../screens/prayers_screen.dart';
import '../../screens/prayer_detail_screen.dart';
import '../../spiritual_nourishment/local_worship/screens/local_worship_screen.dart';
import '../../screens/school_org_calendar_screen.dart';
import '../../admin/screens/admin_sign_in_screen.dart';
import '../gift_activity_link.dart';
import '../prayer_link.dart';
import 'root_navigator.dart';

GoRouter createAppRouter(Ref ref) {
  final homeRefreshKey = ref.watch(homeRefreshKeyProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
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
      GoRoute(
        path: '${GiftActivityLink.pathPrefix}/:id',
        builder: (context, state) => GiftActivityScreen(
          giftId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/activity/:id',
        redirect: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return '/';
          return GiftActivityLink.path(id);
        },
      ),
      GoRoute(
        path: PrayerLink.listPath,
        builder: (context, state) => const PrayersListScreen(),
      ),
      GoRoute(
        path: LocalWorshipScreen.path,
        builder: (context, state) => LocalWorshipScreen(
          initialKindId: state.uri.queryParameters['tab'],
          initialOrgId: state.uri.queryParameters['org'],
        ),
      ),
      GoRoute(
        path: SchoolOrgCalendarScreen.path,
        builder: (context, state) => SchoolOrgCalendarScreen(
          initialOrgId: state.uri.queryParameters['org'],
        ),
      ),
      GoRoute(
        path: '${PrayerLink.pathPrefix}/:id',
        builder: (context, state) => PrayerScreen(
          prayerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/group-invites',
        builder: (context, state) => const PendingGroupInvitesScreen(),
      ),
      GoRoute(
        path: '/admin/sign-in',
        builder: (context, state) => const AdminSignInScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminAccessGate(),
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
