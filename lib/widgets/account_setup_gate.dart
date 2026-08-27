import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';
import '../screens/set_password_screen.dart';
import 'institutional_welcome_dialog.dart';

/// Gates personal app use until password setup and one-time welcome complete.
class AccountSetupGate extends ConsumerStatefulWidget {
  const AccountSetupGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AccountSetupGate> createState() => _AccountSetupGateState();
}

class _AccountSetupGateState extends ConsumerState<AccountSetupGate> {
  bool _welcomeScheduled = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null || user.isAnonymous) {
      return widget.child;
    }

    final profileAsync = ref.watch(userProfileStreamProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile?.needsPasswordSetup == true) {
          return const SetPasswordScreen();
        }

        if (profile?.shouldShowInstitutionalWelcome == true && !_welcomeScheduled) {
          _welcomeScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await InstitutionalWelcomeDialog.show();
            if (!mounted) return;
            await ref.read(userProfileServiceProvider).markInstitutionalWelcomeSeen();
            if (mounted) setState(() => _welcomeScheduled = false);
          });
        }

        return widget.child;
      },
      loading: () => widget.child,
      error: (_, __) => widget.child,
    );
  }
}
