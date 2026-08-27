import 'package:flutter/material.dart';

import '../core/user_text_input.dart';

/// Plain-text composer for a new reflection or an appended entry.
class ReflectionComposer extends StatefulWidget {
  const ReflectionComposer({
    super.key,
    required this.onSubmit,
    this.showTitle = true,
    this.submitLabel = 'Save',
    this.initialTitle,
    this.busy = false,
  });

  final Future<void> Function({String? title, required String body}) onSubmit;
  final bool showTitle;
  final String submitLabel;
  final String? initialTitle;
  final bool busy;

  @override
  State<ReflectionComposer> createState() => _ReflectionComposerState();
}

class _ReflectionComposerState extends State<ReflectionComposer> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.busy) return;
    await widget.onSubmit(
      title: widget.showTitle ? _titleController.text : null,
      body: _bodyController.text,
    );
    if (mounted) {
      _bodyController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          UserTextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
        ],
        UserTextField(
          controller: _bodyController,
          decoration: const InputDecoration(
            labelText: 'Your reflection',
            hintText: 'Write freely — this is private to you.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 8,
          minLines: 4,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: widget.busy ? null : _submit,
            child: widget.busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel),
          ),
        ),
      ],
    );
  }
}
