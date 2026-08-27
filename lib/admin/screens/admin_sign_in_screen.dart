import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_error_messages.dart';
import '../../core/auth/auth_service.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/auth_layout.dart';
import '../providers/admin_providers.dart';
import '../services/admin_access_service.dart';
import 'admin_shell_screen.dart';

/// Dedicated administrator sign-in — same credentials as personal login.
class AdminSignInScreen extends ConsumerStatefulWidget {
  const AdminSignInScreen({super.key});

  @override
  ConsumerState<AdminSignInScreen> createState() => _AdminSignInScreenState();
}

class _AdminSignInScreenState extends ConsumerState<AdminSignInScreen> {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryExistingSession());
  }

  Future<void> _tryExistingSession() async {
    await ref.read(authServiceProvider).waitForAuthReady();
    if (!mounted) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null || user.isAnonymous) return;

    final status = await ref.read(adminAccessServiceProvider).evaluateAccess();
    if (!mounted) return;

    if (status == AdminAccessStatus.authorized) {
      await ref.read(platformAdminServiceProvider).ensureRegistered();
      if (!mounted) return;
      context.go('/admin');
    } else if (status == AdminAccessStatus.memberOnly ||
        status == AdminAccessStatus.guestNotAllowed) {
      setState(() => _inlineError = adminAccessDeniedMessage(status));
    }
  }

  Future<void> _routeAfterAccessCheck() async {
    final status = await ref.read(adminAccessServiceProvider).evaluateAccess();
    if (!mounted) return;

    switch (status) {
      case AdminAccessStatus.authorized:
        await ref.read(platformAdminServiceProvider).ensureRegistered();
        if (!mounted) return;
        context.go('/admin');
      case AdminAccessStatus.memberOnly:
      case AdminAccessStatus.guestNotAllowed:
      case AdminAccessStatus.unauthenticated:
        setState(() {
          _inlineError = adminAccessDeniedMessage(status);
        });
    }
  }

  Future<void> _finishGuestMigration(
    AuthCoordinator coordinator,
    AuthSessionHandoff handoff,
    SessionHistoryNotifier sessionHistory,
  ) async {
    try {
      await coordinator.completeMigration(handoff);
      await sessionHistory.onLoginComplete();
    } catch (e) {
      print('Admin sign-in post-auth: $e');
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final validationError = AuthErrorMessages.validateCredentials(
      email: email,
      password: password,
      isRegister: false,
    );
    if (validationError != null) {
      setState(() => _inlineError = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _inlineError = null;
    });

    try {
      final coordinator = ref.read(authCoordinatorProvider);
      final inMemory = ref.read(sessionHistoryProvider.notifier).current;

      final handoff = await coordinator.signInWithEmailAuthOnly(
        email: email,
        password: password,
        inMemoryHistory: inMemory,
      );

      if (!mounted) return;

      final sessionHistory = ref.read(sessionHistoryProvider.notifier);
      unawaited(_finishGuestMigration(coordinator, handoff, sessionHistory));
      await _routeAfterAccessCheck();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _inlineError = AuthErrorMessages.forException(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _inlineError = AuthErrorMessages.forError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator sign-in'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kAuthFormMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.apartment_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Administrator sign-in',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For authorized school, parish, and ministry leaders only.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use the same email and password as your personal WWJD-DI account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  if (_inlineError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _inlineError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          height: 1.45,
                        ),
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
                      if (_inlineError != null) {
                        setState(() => _inlineError = null);
                      }
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
                    onSubmitted: (_) => _isLoading ? null : _submit(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in as administrator'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : () => context.go('/'),
                    child: const Text('Return to personal use'),
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

/// Gate that verifies admin access before showing [AdminShellScreen].
class AdminAccessGate extends ConsumerStatefulWidget {
  const AdminAccessGate({super.key});

  @override
  ConsumerState<AdminAccessGate> createState() => _AdminAccessGateState();
}

class _AdminAccessGateState extends ConsumerState<AdminAccessGate> {
  AdminAccessStatus? _status;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final auth = ref.read(authServiceProvider);
    if (auth.currentUser == null) {
      await auth.waitForAuthReady();
    }
    if (!mounted) return;

    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) context.go('/admin/sign-in');
      return;
    }

    final status = await ref.read(adminAccessServiceProvider).evaluateAccess();
    if (!mounted) return;

    if (status == AdminAccessStatus.unauthenticated) {
      context.go('/admin/sign-in');
      return;
    }

    if (status == AdminAccessStatus.authorized) {
      await ref.read(platformAdminServiceProvider).ensureRegistered();
    }

    if (!mounted) return;

    setState(() {
      _status = status;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final status = _status;
    if (status == null || status == AdminAccessStatus.authorized) {
      return const AdminShellScreen();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Administrator access')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 56,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 20),
            Text(
              adminAccessDeniedMessage(status),
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5, fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Use WWJD-DI as a personal user'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/admin/sign-in'),
              child: const Text('Try a different account'),
            ),
          ],
        ),
      ),
    );
  }
}
