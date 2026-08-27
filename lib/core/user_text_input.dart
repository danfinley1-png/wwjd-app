import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Spell-check settings for user-authored text (questions, notes, activities).
abstract final class UserTextInput {
  /// Platform spell check with visible misspelling underline (where supported).
  static const SpellCheckConfiguration spellCheck = SpellCheckConfiguration(
    misspelledTextStyle: TextStyle(
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFFC62828),
      decorationStyle: TextDecorationStyle.wavy,
    ),
  );

  static SpellCheckConfiguration get disabled => SpellCheckConfiguration.disabled();

  /// Web/Edge has no built-in spell-check service — use disabled there.
  static SpellCheckConfiguration get forPlatform =>
      kIsWeb ? disabled : spellCheck;
}

/// Applies [UserTextInput.spellCheck] to a [TextField] for free-form user content.
class UserTextField extends StatelessWidget {
  const UserTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      onTap: onTap,
      textCapitalization: textCapitalization,
      autocorrect: true,
      enableSuggestions: true,
      spellCheckConfiguration: UserTextInput.forPlatform,
    );
  }
}
