import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'platform_utils.dart';
import 'responsive_layout.dart';

/// True when we should apply extra-large, forgiving touch targets (mobile browsers).
bool get preferMobileTouchTargets => kIsWeb && isMobileWeb;

/// Comfortable minimum touch size — slightly larger on iPhone/mobile web Safari.
double touchTargetMin(BuildContext context) {
  if (preferMobileTouchTargets) return 52;
  return kMinTouchTarget;
}

/// Icon buttons with padded, reliable hit areas for mobile web.
ButtonStyle mobileIconButtonStyle(BuildContext context) {
  final size = touchTargetMin(context);
  return IconButton.styleFrom(
    minimumSize: Size(size, size),
    tapTargetSize: MaterialTapTargetSize.padded,
    padding: const EdgeInsets.all(10),
    visualDensity: VisualDensity.standard,
  );
}

/// Text buttons with a comfortable minimum height on mobile web.
ButtonStyle mobileTextButtonStyle(BuildContext context) {
  return TextButton.styleFrom(
    minimumSize: Size(64, touchTargetMin(context)),
    tapTargetSize: MaterialTapTargetSize.padded,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

/// Icon + short label for primary touch actions (no hover reliance).
Widget mobileLabeledAction({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
  Color? foregroundColor,
  double iconSize = 18,
}) {
  return TextButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: iconSize),
    label: Text(label),
    style: TextButton.styleFrom(
      foregroundColor: foregroundColor,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ).merge(mobileTextButtonStyle(context)),
  );
}

/// Run [action] after closing an open drawer (required for reliable navigation on iPhone Safari).
void runSidebarAction(ScaffoldState? scaffold, VoidCallback action) {
  if (scaffold != null && scaffold.isDrawerOpen) {
    scaffold.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      action();
    });
    return;
  }
  action();
}

/// Bottom inset when the keyboard is open. Avoid animating on mobile web —
/// iOS Safari can misalign taps while [AnimatedPadding] is in flight.
EdgeInsets keyboardBottomPadding(BuildContext context) {
  return EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom);
}

bool get useInstantKeyboardPadding => kIsWeb && isMobileWeb;

/// Wraps [child] with keyboard-aware bottom padding.
Widget keyboardAwarePadding({
  required BuildContext context,
  required Widget child,
}) {
  final padding = keyboardBottomPadding(context);
  if (useInstantKeyboardPadding) {
    return Padding(padding: padding, child: child);
  }
  return AnimatedPadding(
    duration: const Duration(milliseconds: 150),
    padding: padding,
    child: child,
  );
}

/// Shows a bottom-sheet picker on mobile web instead of a native overlay dropdown.
Future<T?> showMobilePickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T) label,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...options.map(
                (option) => ListTile(
                  minVerticalPadding: 12,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(label(option)),
                  trailing: option == selected
                      ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, option),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Dropdown that uses a tappable bottom sheet on mobile web (more reliable on iOS).
class MobileFriendlyDropdown extends StatelessWidget {
  const MobileFriendlyDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (preferMobileTouchTargets) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          enabled: enabled,
        ),
        child: InkWell(
          onTap: enabled
              ? () async {
                  final picked = await showMobilePickerSheet<String>(
                    context: context,
                    title: label,
                    options: items,
                    label: (v) => v,
                    selected: value,
                  );
                  if (picked != null) onChanged(picked);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text(value)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      isExpanded: true,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: enabled ? (v) { if (v != null) onChanged(v); } : null,
    );
  }
}
