import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'usage_analytics_service.dart';
import 'usage_device_class.dart';

/// Starts aggregate session tracking after Firebase Auth is ready.
class UsageAnalyticsBootstrap extends ConsumerStatefulWidget {
  const UsageAnalyticsBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UsageAnalyticsBootstrap> createState() =>
      _UsageAnalyticsBootstrapState();
}

class _UsageAnalyticsBootstrapState extends ConsumerState<UsageAnalyticsBootstrap>
    with WidgetsBindingObserver {
  bool _sessionStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    UsageAnalyticsService.instance.endSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      UsageAnalyticsService.instance.endSession();
    } else if (state == AppLifecycleState.resumed && _sessionStarted) {
      _sessionStarted = false;
      _startSession();
    }
  }

  Future<void> _startSession() async {
    if (_sessionStarted || !mounted) return;

    final auth = ref.read(authServiceProvider);
    await auth.waitForAuthReady();

    var user = auth.currentUser;
    if (user == null) {
      await ref.read(authCoordinatorProvider).ensureSession(allowGuest: true);
      user = auth.currentUser;
    }
    if (user == null || !mounted) return;

    _sessionStarted = true;
    final device = UsageDeviceClass.detect(context: context);
    await UsageAnalyticsService.instance.startSession(device);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
