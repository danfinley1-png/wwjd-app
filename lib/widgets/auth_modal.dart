import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:go_router/go_router.dart';

import '../core/providers/app_providers.dart';
import '../core/auth/auth_service.dart';
import 'auth_layout.dart';

void showAuthModal(
  BuildContext context,
  WidgetRef ref, {
  bool navigateHomeOnSuccess = true,
  VoidCallback? onAuthSuccess,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => AuthModalSheet(
      navigateHomeOnSuccess: navigateHomeOnSuccess,
      onAuthSuccess: onAuthSuccess,
    ),
  );
}

class AuthModalSheet extends ConsumerStatefulWidget {
  const AuthModalSheet({
    super.key,
    this.navigateHomeOnSuccess = true,
    this.onAuthSuccess,
  });

  final bool navigateHomeOnSuccess;
  final VoidCallback? onAuthSuccess;

  @override
  ConsumerState<AuthModalSheet> createState() => _AuthModalSheetState();
}

class _AuthModalSheetState extends ConsumerState<AuthModalSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _completeAuth(
    Future<AuthMigrationResult> Function() action,
  ) async {
    setState(() => _isLoading = true);
    try {
      final result = await action();

      if (!mounted) return;
      Navigator.pop(context);

      if (!context.mounted) return;
      showMigrationSnackBar(context, result);
      widget.onAuthSuccess?.call();
      if (widget.navigateHomeOnSuccess) {
        context.go('/');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    final coordinator = ref.read(authCoordinatorProvider);
    final inMemory = ref.read(sessionHistoryProvider.notifier).current;

    if (_isRegisterMode) {
      await _completeAuth(() => coordinator.registerWithEmail(
            email: email,
            password: password,
            inMemoryHistory: inMemory,
          ));
    } else {
      await _completeAuth(() => coordinator.signInWithEmail(
            email: email,
            password: password,
            inMemoryHistory: inMemory,
          ));
    }
  }

  Future<void> _signInWithGoogle() async {
    final coordinator = ref.read(authCoordinatorProvider);
    final inMemory = ref.read(sessionHistoryProvider.notifier).current;
    await _completeAuth(() => coordinator.signInWithGoogle(
          inMemoryHistory: inMemory,
        ));
  }

  Future<void> _continueAsGuest() async {
    Navigator.pop(context);
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
          Text(
            _isRegisterMode ? 'Create Account' : 'Welcome Back',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _isRegisterMode
                ? 'Register to save your journey across devices'
                : 'Sign in to save your journey',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _isLoading ? null : _submitEmail(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitEmail,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isRegisterMode ? 'Register' : 'Sign In'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _signInWithGoogle,
              child: const Text('Sign in with Google'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() => _isRegisterMode = !_isRegisterMode),
            child: Text(
              _isRegisterMode
                  ? 'Already have an account? Sign in'
                  : 'Need an account? Register',
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _continueAsGuest,
            child: const Text('Continue as Guest'),
          ),
        ],
      ),
    );
  }
}
