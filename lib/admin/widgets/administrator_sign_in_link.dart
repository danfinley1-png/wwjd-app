import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/admin_config.dart';

/// Discreet entry point for the Admin area on welcome / login surfaces.
class AdministratorSignInLink extends StatelessWidget {
  const AdministratorSignInLink({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdminConfig.adminLayerEnabled) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Divider(height: 1, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.push('/admin/sign-in'),
            child: const Text('Administrator sign-in'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'For authorized school, parish, and ministry leaders only.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
