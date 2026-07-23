import 'package:flutter/material.dart';

/// Layout breakpoints aligned with Material guidance.
const double kCompactPhoneBreakpoint = 600;
const double kDesktopBreakpoint = 900;

/// True for typical phone widths (360–430px) and small phablets.
bool isCompactWidth(BuildContext context) {
  return MediaQuery.sizeOf(context).width < kCompactPhoneBreakpoint;
}

/// Minimum recommended touch target (Material / WCAG).
const double kMinTouchTarget = 48;

/// Horizontal padding that scales down on narrow screens.
EdgeInsets responsiveHorizontalPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 400) return const EdgeInsets.symmetric(horizontal: 12);
  if (width < kCompactPhoneBreakpoint) return const EdgeInsets.symmetric(horizontal: 16);
  return const EdgeInsets.symmetric(horizontal: 24);
}

/// Max dialog width that never exceeds screen minus margins.
double responsiveDialogMaxWidth(BuildContext context, {double max = 420}) {
  final available = MediaQuery.sizeOf(context).width - 32;
  return available.clamp(280, max);
}

/// Stacked actions on phone, row on wider layouts.
class ResponsiveDialogActions extends StatelessWidget {
  const ResponsiveDialogActions({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFirst = false,
  });

  final Widget primary;
  final Widget secondary;
  final bool primaryFirst;

  @override
  Widget build(BuildContext context) {
    if (!isCompactWidth(context)) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: primaryFirst
            ? [primary, const SizedBox(width: 8), secondary]
            : [secondary, const SizedBox(width: 8), primary],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: primaryFirst
          ? [primary, const SizedBox(height: 8), secondary]
          : [secondary, const SizedBox(height: 8), primary],
    );
  }
}
