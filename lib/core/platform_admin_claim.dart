import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../admin/config/admin_config.dart';

/// Platform admin for client UI — uses ID token custom claim (not Firestore).
class PlatformAdminClaim {
  PlatformAdminClaim._();

  static bool isFoundationAdmin(User? user) {
    return AdminConfig.isFoundationAdmin(user?.email);
  }

  static bool hasAdminClaim(Map<String, dynamic>? claims) {
    return claims?['admin'] == true;
  }

  /// One line for a permission denial. `admin` is `request.auth.token.admin`.
  static Future<String> rulesDebugLine(FirebaseAuth auth) async {
    final user = auth.currentUser;
    if (user == null) return 'uid=(none) admin=false';
    var admin = false;
    try {
      final token = await user.getIdTokenResult();
      admin = hasAdminClaim(token.claims);
    } catch (e) {
      debugPrint('PlatformAdminClaim.rulesDebugLine: $e');
    }
    final email = user.email ?? '';
    return 'uid=${user.uid} admin=$admin email=$email';
  }

  static Future<bool> isPlatformAdmin(FirebaseAuth auth) async {
    final user = auth.currentUser;
    if (user == null) return false;
    if (isFoundationAdmin(user)) return true;
    try {
      final result = await user.getIdTokenResult();
      return hasAdminClaim(result.claims);
    } catch (e) {
      debugPrint('PlatformAdminClaim.isPlatformAdmin: $e');
      return false;
    }
  }

  /// Re-emits when auth or refreshed token claims change.
  static Stream<bool> watchPlatformAdmin(FirebaseAuth auth) {
    return auth.idTokenChanges().asyncExpand((user) async* {
      if (user == null) {
        yield false;
        return;
      }
      if (isFoundationAdmin(user)) {
        yield true;
        return;
      }
      try {
        final result = await user.getIdTokenResult();
        yield hasAdminClaim(result.claims);
      } catch (e) {
        debugPrint('PlatformAdminClaim.watchPlatformAdmin: $e');
        yield false;
      }
    });
  }
}
