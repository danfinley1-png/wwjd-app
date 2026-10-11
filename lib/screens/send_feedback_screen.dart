import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';
import '../core/services/product_feedback_service.dart';
import '../models/product_feedback.dart';
import '../models/user_profile.dart';

/// Profile form for app issues — not spiritual journaling.
class SendFeedbackScreen extends ConsumerStatefulWidget {
  const SendFeedbackScreen({super.key});

  @override
  ConsumerState<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

class _SendFeedbackScreenState extends ConsumerState<SendFeedbackScreen> {
  final _textController = TextEditingController();
  ProductFeedbackType? _type;
  bool _busy = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      setState(() => _error = 'Sign in to send feedback.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final profile = ref.read(userProfileStreamProvider).valueOrNull;
      final email = user.email;
      final name = profile?.hasDisplayName(email) == true
          ? profile!.effectiveDisplayName
          : (UserProfile.isValidDisplayName(user.displayName, accountEmail: email)
              ? user.displayName
              : null);

      await ref.read(productFeedbackServiceProvider).submitProfileFeedback(
            text: _textController.text,
            type: _type,
            displayName: name,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _submitted = true;
      });
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message?.toString() ?? 'Enter a short note about the app.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send feedback'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_submitted) ...[
            const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF2E7D32)),
            const SizedBox(height: 16),
            const Text(
              ProductFeedbackService.confirmationMessage,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ] else ...[
            const Text(
              'Tell the WWJD-DI team about the app — a bug, a suggestion, '
              'or something else. This is not a spiritual journal and is not '
              'shared with group leaders.',
              style: TextStyle(height: 1.5, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _textController,
              maxLength: ProductFeedback.maxTextLength,
              maxLines: 5,
              enabled: signedIn && !_busy,
              decoration: const InputDecoration(
                labelText: 'Your note',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Type (optional)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final type in ProductFeedbackType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: _busy
                        ? null
                        : (selected) {
                            setState(() => _type = selected ? type : null);
                          },
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.red.shade800)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: signedIn && !_busy ? _submit : null,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
            if (!signedIn) ...[
              const SizedBox(height: 12),
              const Text('Sign in to send feedback.'),
            ],
          ],
        ],
      ),
    );
  }
}
