import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Sign In
  Future<User?> signInWithGoogle() async {
    // ... your existing Google code ...
    // (keep whatever you already have here)
  }

  // Email + Password Sign In
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      print('Email sign in error: $e');
      rethrow;
    }
  }

  // Get current user (new)
  Future<User?> getCurrentUser() async {
    try {
      return _auth.currentUser;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}