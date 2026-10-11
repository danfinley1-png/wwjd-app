import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/platform_admin_claim.dart';

/// Error text plus the uid and `admin` claim Firestore rules check.
class AdminRulesDebugText extends StatelessWidget {
  const AdminRulesDebugText({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<String>(
          future: PlatformAdminClaim.rulesDebugLine(FirebaseAuth.instance),
          builder: (context, snap) {
            final line = snap.data ?? 'uid=… admin=…';
            return Text(
              '$message\n$line',
              textAlign: TextAlign.center,
            );
          },
        ),
      ),
    );
  }
}
