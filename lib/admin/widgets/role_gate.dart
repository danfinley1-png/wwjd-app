import 'package:flutter/material.dart';

/// Shows [child] only when [allowed] is true; otherwise [fallback] or nothing.
class RoleGate extends StatelessWidget {
  const RoleGate({
    super.key,
    required this.allowed,
    required this.child,
    this.fallback,
  });

  final bool allowed;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    if (allowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
