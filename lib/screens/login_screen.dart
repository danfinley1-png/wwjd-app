import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../core/auth/auth_error_messages.dart';
import '../core/providers/app_providers.dart';
import '../core/auth/auth_service.dart';
import '../widgets/auth_layout.dart';
import '../admin/widgets/administrator_sign_in_link.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

  void _showError(String message) {
    setState(() => _inlineError = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _completeAuth(Future<AuthMigrationResult> Function() action) async {
    setState(() {
      _isLoading = true;
      _inlineError = null;
    });
    try {
      final result = await action();

      if (!mounted) return;
      showMigrationSnackBar(context, result);

      unawaited(
        ref.read(sessionHistoryProvider.notifier).onLoginComplete().catchError(
          (Object e) => print('LoginScreen: history sync failed: $e'),
        ),
      );

      Navigator.pushReplacementNamed(context, '/home');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kAuthFormMaxWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.church, size: 80, color: Colors.brown),
                  const SizedBox(height: 24),
                  const Text(
                    'WWJD',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'What Would Jesus Do?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'Sign In or Register',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
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
                    enabled: !_isLoading,
                    onChanged: (_) {
                      if (_inlineError != null) setState(() => _inlineError = null);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _submit(isRegister: false),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          : const Text('Log In — Existing User'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => _submit(isRegister: true),
                      child: const Text('I\'m New — Register'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            try {
                              await ref.read(authCoordinatorProvider).continueAsGuest();
                              await ref.read(sessionHistoryProvider.notifier).initialize();
                              if (mounted) {
                                Navigator.pushReplacementNamed(context, '/home');
                              }
                            } catch (e) {
                              if (mounted) {
                                _showError('Guest session error: $e');
                              }
                            }
                          },
                    child: const Text('Continue as Guest'),
                  ),
                  const AdministratorSignInLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
