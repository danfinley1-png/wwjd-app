import 'package:flutter/material.dart';
import 'auth_service.dart';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? get currentUser => _authService.currentUser;
  bool get isAuthenticated => _authService.currentUser != null;

  AppAuthProvider() {
    _authService.authStateChanges.listen((_) => notifyListeners());
  }

  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }
}