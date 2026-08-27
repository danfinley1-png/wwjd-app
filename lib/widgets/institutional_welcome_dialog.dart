import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/routing/root_navigator.dart';

/// One-time welcome for admin-provisioned institutional users.
class InstitutionalWelcomeDialog {
  InstitutionalWelcomeDialog._();

  /// Shows the welcome dialog using the app root navigator.
  ///
  /// [context] is optional — when omitted (or when it has no Navigator ancestor),
  /// [rootNavigatorKey] from GoRouter is used instead.
  static Future<void> show([BuildContext? context]) {
    final dialogContext = _resolveContext(context);
    if (dialogContext == null) return Future.value();

    return showDialog<void>(
      context: dialogContext,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Welcome to ${AppConfig.appName}'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WWJD-DI is a Catholic companion for discernment — rooted in '
                'Scripture, the Catechism, and the living teaching of the Church.',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                'A few important guardrails:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                '• Your personal conversations, reflections, and history are '
                'private. Administrators cannot read them.\n'
                '• When you choose to share content, anonymity and dignity '
                'protections apply.\n'
                '• Responses are guided by Catholic teaching — Scripture, the '
                'Catechism, and the Magisterium.\n'
                '• If you are in danger or being harmed, please seek real-world '
                'help from a trusted adult, pastor, counselor, or emergency services.',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                'You may begin with Seeking God\'s Wisdom or explore the other '
                'tools at your own pace. Peace be with you.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Begin'),
          ),
        ],
      ),
    );
  }

  static BuildContext? _resolveContext(BuildContext? context) {
    if (context != null) {
      final navigator = Navigator.maybeOf(context, rootNavigator: true);
      if (navigator != null) return context;
    }
    return rootNavigatorKey.currentContext;
  }
}
