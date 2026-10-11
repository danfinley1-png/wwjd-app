import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../email/institutional_email_copy.dart';

/// Admin-only preview of a transactional email before Send.
Future<EmailSendDraft?> showEmailPreviewDialog({
  required BuildContext context,
  required String title,
  required String toLabel,
  required String subject,
  required String body,
  String? helperText,
}) {
  return showDialog<EmailSendDraft>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => EmailPreviewDialog(
      title: title,
      toLabel: toLabel,
      initialSubject: subject,
      initialBody: body,
      helperText: helperText,
    ),
  );
}

class EmailPreviewDialog extends StatefulWidget {
  const EmailPreviewDialog({
    super.key,
    required this.title,
    required this.toLabel,
    required this.initialSubject,
    required this.initialBody,
    this.helperText,
  });

  final String title;
  final String toLabel;
  final String initialSubject;
  final String initialBody;
  final String? helperText;

  @override
  State<EmailPreviewDialog> createState() => _EmailPreviewDialogState();
}

class _EmailPreviewDialogState extends State<EmailPreviewDialog> {
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.initialSubject);
    _bodyController = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _submit({required bool edited}) {
    final subject = _subjectController.text.trim();
    final text = _bodyController.text.trim();
    if (subject.isEmpty || text.isEmpty) return;
    Navigator.pop(
      context,
      EmailSendDraft(subject: subject, text: text, edited: edited || _editing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.helperText != null) ...[
                  Text(
                    widget.helperText!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'From: ${InstitutionalEmailCopy.fromAddress}',
                  style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                ),
                Text(
                  'To: ${widget.toLabel}',
                  style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (_editing) ...[
                  TextField(
                    controller: _subjectController,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bodyController,
                    minLines: 10,
                    maxLines: 18,
                    maxLength: 8000,
                    decoration: const InputDecoration(
                      labelText: 'Body',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ] else
                  _EmailRecipientPreview(
                    subject: _subjectController.text,
                    body: _bodyController.text,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!_editing)
          TextButton(
            onPressed: () => setState(() => _editing = true),
            child: const Text('Edit then send'),
          ),
        FilledButton(
          onPressed: () => _submit(edited: _editing),
          child: const Text('Send'),
        ),
      ],
    );
  }
}

class _EmailRecipientPreview extends StatelessWidget {
  const _EmailRecipientPreview({
    required this.subject,
    required this.body,
  });

  final String subject;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                InstitutionalEmailCopy.logoUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.church,
                  size: 72,
                  color: AppColors.primaryMaroon,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'WWJD-DI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryMaroon,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Subject: $subject',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              body,
              style: const TextStyle(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
