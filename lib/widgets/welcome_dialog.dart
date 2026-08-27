import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../core/config.dart';
import '../core/providers/app_providers.dart';
import '../core/responsive_layout.dart';
import 'auth_layout.dart';
import 'auth_modal.dart';
import '../admin/widgets/administrator_sign_in_link.dart';

void showWelcomeDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => ResponsiveAuthDialog(
      title: Builder(
        builder: (context) {
          final compact = isCompactWidth(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.church,
                    color: AppColors.primaryMaroon,
                    size: compact ? 28 : 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppConfig.guestWelcomeTitle,
                      style: TextStyle(
                        fontSize: compact ? 20 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                AppConfig.guestWelcomeInvite,
                style: TextStyle(
                  fontSize: compact ? 15 : 16,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          );
        },
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          const Text(
            AppConfig.guestWelcomeBody,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 20),
          const Text(
            AppConfig.guestWelcomeClosing,
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(kMinTouchTarget),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              showAuthModal(context, ref);
            },
            child: const Text('Sign Up / Log In'),
          ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(kMinTouchTarget),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
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
          const AdministratorSignInLink(),
        ],
      ),
    ),
  );
}
