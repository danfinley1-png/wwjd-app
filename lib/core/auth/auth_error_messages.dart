import 'package:firebase_auth/firebase_auth.dart';

/// User-facing messages for Firebase Auth errors and basic field validation.
class AuthErrorMessages {
  AuthErrorMessages._();

  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  static String? validateCredentials({
    required String email,
    required String password,
    required bool isRegister,
  }) {
    if (email.isEmpty || password.isEmpty) {
      return 'Please enter your email and password.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    if (isRegister && password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  static String forException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support if you need help.';
      case 'user-not-found':
        return 'No account found with this email. Choose "I\'m New — Register" to create one.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Choose "Log In" if you have an account.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email sign-in is not available right now. Please try again later.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'timeout':
        return 'That took too long. Check your connection and try again.';
      case 'requires-recent-login':
        return 'For security, please sign in again and retry.';
      default:
        final msg = e.message?.trim();
        if (msg != null && msg.isNotEmpty) return msg;
        return 'Authentication failed. Please try again.';
    }
  }

  static String forError(Object error) {
    if (error is FirebaseAuthException) {
      return forException(error);
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
