import 'package:flutter/material.dart';
import '../walk_together_screen.dart';

class ShareButton extends StatelessWidget {
  final String question;
  final String response;
  final String? title;

  const ShareButton({
    super.key,
    required this.question,
    required this.response,
    this.title,
  });

  void _showShareOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Anonymously'),
        content: const Text(
          'This will share your question + WWJD response anonymously to the community.\n\n'
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
              _shareToWalkTogether(context);
            },
            child: const Text('Walk Together (Community)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing to Specific Group coming soon')),
              );
            },
            child: const Text('Specific Group'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing to Individual coming soon')),
              );
            },
            child: const Text('Individual'),
          ),
        ],
      ),
    );
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
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.share, size: 20),
      label: const Text('Share'),
      onPressed: () => _showShareOptions(context),
    );
  }
}