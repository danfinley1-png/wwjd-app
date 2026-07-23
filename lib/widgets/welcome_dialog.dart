import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';
import 'auth_layout.dart';
import 'auth_modal.dart';

void showWelcomeDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => ResponsiveAuthDialog(
      title: const Row(
        children: [
          Icon(Icons.church, color: Color(0xFF8B1E1E), size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Text('Welcome to WWJD'),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bring your questions, struggles, and decisions.\n\n'
            'Receive warm, faithful Catholic guidance rooted in Scripture and Church teaching.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          SizedBox(height: 24),
          Text(
            'Your journey, guided by faith.',
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ],
      ),
      actions: AuthDialogActions(
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              showAuthModal(context, ref);
            },
            child: const Text('Sign Up / Log In'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(authCoordinatorProvider).continueAsGuest();
                await ref.read(sessionHistoryProvider.notifier).initialize();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not start guest session: $e')),
                  );
                }
              }
            },
            child: const Text('Continue as Guest'),
          ),
        ],
      ),
    ),
  );
}
