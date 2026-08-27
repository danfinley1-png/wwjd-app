import 'package:flutter/material.dart';

import '../core/responsive_layout.dart';

/// Max width for auth forms on web / wide layouts.
const double kAuthFormMaxWidth = 420;
/// Scrollable, width-constrained column for modal auth forms.
class AuthFormContainer extends StatelessWidget {
  const AuthFormContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 32, 24, 24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return SafeArea(
      child: Padding(
        padding: padding.copyWith(bottom: padding.bottom + bottomInset),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: kAuthFormMaxWidth,
              maxHeight: maxHeight,
            ),
            child: SingleChildScrollView(
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width primary/secondary buttons stacked for narrow dialogs.
class AuthDialogActions extends StatelessWidget {
  const AuthDialogActions({
    super.key,
    required this.actions,
  });

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          actions[i],
        ],
      ],
    );
  }
}

/// Width-constrained [AlertDialog] for web and mobile.
class ResponsiveAuthDialog extends StatelessWidget {
  const ResponsiveAuthDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
  });

  final Widget title;
  final Widget content;
  final Widget? actions;

  List<Widget>? get _actionWidgets {
    final widget = actions;
    if (widget is AuthDialogActions) return widget.actions;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactWidth(context);
    final dialogWidth = responsiveDialogMaxWidth(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxBodyHeight = MediaQuery.sizeOf(context).height -
        viewInsets.bottom -
        (compact ? 120 : 140);
    final actionWidgets = _actionWidgets;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 20,
        vertical: compact ? 16 : 24,
      ),
      title: title,
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxBodyHeight.clamp(280, 720),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: viewInsets.bottom > 0 ? 8 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                if (actionWidgets != null) ...[
                  const SizedBox(height: 16),
                  AuthDialogActions(actions: actionWidgets),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
