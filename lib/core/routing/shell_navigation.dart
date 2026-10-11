import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'root_navigator.dart';

/// Leave Saints (and any imperative overlays) and show Home — one shell, no nesting.
void goToAppHome(BuildContext context) {
  final router = GoRouter.of(context);
  final rootNav = rootNavigatorKey.currentState;
  if (rootNav != null) {
    rootNav.popUntil((route) => route.isFirst);
  } else {
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }
  while (router.canPop()) {
    router.pop();
  }
  router.go('/');
}
