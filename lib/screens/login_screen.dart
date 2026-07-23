import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/providers/app_providers.dart';
import '../core/auth/auth_service.dart';
import '../widgets/auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegisterMode = false;

  Future<void> _completeAuth(Future<AuthMigrationResult> Function() action) async {
    setState(() => _isLoading = true);
    try {
      final result = await action();

      if (!mounted) return;
      showMigrationSnackBar(context, result);
      Navigator.pushReplacementNamed(context, '/home');
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
    final coordinator = ref.read(authCoordinatorProvider);
    final inMemory = ref.read(sessionHistoryProvider.notifier).current;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

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
              const SizedBox(height: 60),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitEmail,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : Text(_isRegisterMode ? 'Register' : 'Sign In'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final coordinator = ref.read(authCoordinatorProvider);
                          final inMemory =
                              ref.read(sessionHistoryProvider.notifier).current;
                          await _completeAuth(() => coordinator.signInWithGoogle(
                                inMemoryHistory: inMemory,
                              ));
                        },
                  child: const Text('Sign in with Google'),
                ),
              ),
              const SizedBox(height: 16),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Guest session error: $e')),
                            );
                          }
                        }
                      },
                child: const Text('Continue as Guest'),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
