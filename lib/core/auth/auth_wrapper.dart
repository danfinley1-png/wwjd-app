import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_auth_provider.dart';
import '../../screens/home_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}