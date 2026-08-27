import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_error_messages.dart';
import '../core/providers/app_providers.dart';
import '../core/auth/auth_service.dart';
import '../core/user_text_input.dart';
import '../core/platform_utils.dart';
import '../admin/widgets/administrator_sign_in_link.dart';
import 'auth_layout.dart';

void showAuthModal(
  BuildContext context,
  WidgetRef ref, {
  bool navigateHomeOnSuccess = true,
  VoidCallback? onAuthSuccess,
}) {
  final useDialog = kIsWeb && isMobileWeb;

  if (useDialog) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: AuthModalSheet(
          navigateHomeOnSuccess: navigateHomeOnSuccess,
          onAuthSuccess: onAuthSuccess,
          onRequestClose: () {
            final nav = Navigator.of(dialogContext, rootNavigator: true);
            if (nav.canPop()) nav.pop();
          },
        ),
      ),
    );
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => AuthModalSheet(
      navigateHomeOnSuccess: navigateHomeOnSuccess,
      onAuthSuccess: onAuthSuccess,
      onRequestClose: () {
        if (Navigator.of(sheetContext).canPop()) {
          Navigator.of(sheetContext).pop();
        }
      },
    ),
  );
}

class AuthModalSheet extends ConsumerStatefulWidget {
  const AuthModalSheet({
    super.key,
    this.navigateHomeOnSuccess = true,
    this.onAuthSuccess,
    this.onRequestClose,
  });

  final bool navigateHomeOnSuccess;
  final VoidCallback? onAuthSuccess;
  final VoidCallback? onRequestClose;

  @override
  ConsumerState<AuthModalSheet> createState() => _AuthModalSheetState();
}

class _AuthModalSheetState extends ConsumerState<AuthModalSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _inlineError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _closeModal() {
    if (widget.onRequestClose != null) {
      widget.onRequestClose!();
      return;
    }
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) rootNav.pop();
  }

  void _showError(String message) {
    setState(() => _inlineError = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _runPostAuth(
    AuthSessionHandoff handoff,
    BuildContext scaffoldContext, {
    required AuthCoordinator coordinator,
    required SessionHistoryNotifier sessionHistory,
  }) async {
    try {
      final result = await coordinator
          .completeMigration(handoff)
          .timeout(const Duration(seconds: 30));
      if (scaffoldContext.mounted) {
        showMigrationSnackBar(scaffoldContext, result);
      }
    } catch (e) {
      if (scaffoldContext.mounted) {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            content: Text(
              'Signed in — syncing your journey in the background. ($e)',
            ),
          ),
        );
      }
    }

    try {
      await sessionHistory.onLoginComplete();
    } catch (e) {
      print('AuthModal post-auth history sync: $e');
    }
  }

  Future<void> _completeAuth(
    Future<AuthSessionHandoff> Function() authAction,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (kIsWeb && isMobileWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    setState(() {
      _isLoading = true;
      _inlineError = null;
    });
    final scaffoldContext = context;

    try {
      final handoff = await authAction().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw FirebaseAuthException(
          code: 'timeout',
          message: AuthErrorMessages.forException(
            FirebaseAuthException(code: 'timeout'),
          ),
        ),
      );

      if (!mounted) return;

      final coordinator = ref.read(authCoordinatorProvider);
      final sessionHistory = ref.read(sessionHistoryProvider.notifier);

      ref.read(homeRefreshKeyProvider.notifier).state++;
      widget.onAuthSuccess?.call();

      _closeModal();

      if (widget.navigateHomeOnSuccess && scaffoldContext.mounted) {
        scaffoldContext.go('/');
      }

      unawaited(_runPostAuth(
        handoff,
        scaffoldContext,
        coordinator: coordinator,
        sessionHistory: sessionHistory,
      ));
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(AuthErrorMessages.forException(e));
    } catch (e) {
      if (mounted) _showError(AuthErrorMessages.forError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit({required bool isRegister}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final validationError = AuthErrorMessages.validateCredentials(
      email: email,
      password: password,
      isRegister: isRegister,
    );
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    final coordinator = ref.read(authCoordinatorProvider);
    final inMemory = ref.read(sessionHistoryProvider.notifier).current;

    if (isRegister) {
      await _completeAuth(() => coordinator.registerWithEmailAuthOnly(
            email: email,
            password: password,
            inMemoryHistory: inMemory,
          ));
    } else {
      await _completeAuth(() => coordinator.signInWithEmailAuthOnly(
            email: email,
            password: password,
            inMemoryHistory: inMemory,
          ));
    }
  }

  Future<void> _continueAsGuest() async {
    _closeModal();
    try {
      await ref.read(authCoordinatorProvider).continueAsGuest();
      await ref.read(sessionHistoryProvider.notifier).initialize();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Guest session error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Sign In or Register',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your email and password, then choose Log In or Register.',
            textAlign: TextAlign.center,
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 16),
            Text(
              _inlineError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_isLoading,
            onChanged: (_) {
              if (_inlineError != null) setState(() => _inlineError = null);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            spellCheckConfiguration: UserTextInput.disabled,
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            onChanged: (_) {
              if (_inlineError != null) setState(() => _inlineError = null);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _submit(isRegister: false),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Log In — Existing User'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => _submit(isRegister: true),
              child: const Text('I\'m New — Register'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : _continueAsGuest,
            child: const Text('Continue as Guest'),
          ),
          const AdministratorSignInLink(),
        ],
      ),
    );
  }
}
