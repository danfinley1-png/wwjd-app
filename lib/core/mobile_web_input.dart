import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mobile_touch.dart';
import 'platform_utils.dart';

/// Requests focus and nudges the OS keyboard on mobile browsers (iOS Safari).
Future<void> requestMobileWebKeyboard(FocusNode node) async {
  if (!node.canRequestFocus) return;
  node.requestFocus();
  if (!kIsWeb || !isMobileWeb) return;

  await Future<void>.delayed(const Duration(milliseconds: 50));
  try {
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  } catch (_) {
    // Best-effort; some web embedders omit TextInput.show.
  }
}

/// Runs [action] after closing an open drawer, without blocking the tap response.
void runAfterDrawerClosed(
  ScaffoldState? scaffold,
  VoidCallback action, {
  bool mounted = true,
}) {
  if (!mounted) return;
  runSidebarAction(scaffold, action);
}
