import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../core/providers/app_providers.dart';

/// Compact Helpful? Yes / No on a Seeking God's Wisdom reply.
///
/// Submits only the flag and an optional theme tag — never the question text.
class ReplyHelpfulVote extends ConsumerStatefulWidget {
  const ReplyHelpfulVote({
    super.key,
    this.theme,
  });

  final String? theme;

  @override
  ConsumerState<ReplyHelpfulVote> createState() => _ReplyHelpfulVoteState();
}

class _ReplyHelpfulVoteState extends ConsumerState<ReplyHelpfulVote> {
  bool _busy = false;
  bool? _choice;

  Future<void> _vote(bool helpful) async {
    if (_busy || _choice != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(productFeedbackServiceProvider).submitHelpfulVote(
            helpful: helpful,
            theme: widget.theme,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _choice = helpful;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save that vote: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_choice != null) {
      return const Text(
        'Thank you.',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Helpful?',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: _busy ? null : () => _vote(true),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Yes', style: TextStyle(fontSize: 12)),
        ),
        TextButton(
          onPressed: _busy ? null : () => _vote(false),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('No', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
