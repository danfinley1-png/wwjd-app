// lib/widgets/welcome_dialog.dart
import 'package:flutter/material.dart';
import 'auth_modal.dart';

void showWelcomeDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.church, color: Color(0xFF8B1E1E), size: 32),
          SizedBox(width: 12),
          Text('Welcome to WWJD'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
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
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Continue as Guest'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            showAuthModal(context);
          },
          child: const Text('Sign Up / Log In'),
        ),
      ],
    ),
  );
}