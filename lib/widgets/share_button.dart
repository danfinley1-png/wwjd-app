import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/providers/app_providers.dart';
import '../walk_together_screen.dart';

class ShareButton extends ConsumerWidget {
  final String question;
  final String response;
  final String? title;

  const ShareButton({
    super.key,
    required this.question,
    required this.response,
    this.title,
  });

  void _showShareOptions(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Reflection'),
        content: const Text(
          'Share a link to this question and WWJD response. '
          'Please ensure no personal or confidential information is included.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _shareDeepLink(context, ref);
            },
            child: const Text('Share Link', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _shareToWalkTogether(context);
            },
            child: const Text('Walk Together'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareDeepLink(BuildContext context, WidgetRef ref) async {
    try {
      final shareService = ref.read(shareServiceProvider);
      final auth = ref.read(authServiceProvider);
      final shareId = await shareService.createShare(
        question: question,
        response: response,
        title: title,
        createdByUid: auth.currentUser?.uid,
      );
      final url = shareService.buildShareUrl(shareId);
      final preview = question.length > 120
          ? '${question.substring(0, 117)}...'
          : question;

      await SharePlus.instance.share(
        ShareParams(
          uri: Uri.parse(url),
          subject: title ?? 'WWJD Shared Reflection',
          text: 'Someone shared a WWJD reflection with you.\n\n$preview\n\n$url',
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share link ready')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    }
  }

  void _shareToWalkTogether(BuildContext context) {
    WalkTogetherScreen.addSharedJourney({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title ?? 'Shared Ethical Journey',
      'question': question,
      'response': response,
      'upvotes': 0,
      'timestamp': DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shared anonymously to Walk Together!')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.share_outlined, size: 22),
      tooltip: 'Share reflection',
      onPressed: () => _showShareOptions(context, ref),
    );
  }
}
