import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../config/admin_config.dart';
import '../models/platform_admin.dart';

/// Platform-level (Super / Overall) administrator operations.
class PlatformAdminService {
  PlatformAdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _platformAdmins =>
      _firestore.collection('platformAdmins');

  bool get isFoundationAdminEmail {
    return AdminConfig.isFoundationAdmin(_auth.currentUser?.email);
  }

  Stream<bool> watchIsSuperAdmin() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);
    if (AdminConfig.isFoundationAdmin(user.email)) {
      return Stream.value(true);
    }
    return _platformAdmins
        .doc(user.uid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  Future<bool> isSuperAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (AdminConfig.isFoundationAdmin(user.email)) return true;
    final snap = await _platformAdmins.doc(user.uid).get();
    return snap.exists;
  }

  /// Registers foundation admin in Firestore (via Cloud Function when available).
  Future<void> ensureRegistered() async {
    final user = _auth.currentUser;
    if (user == null || !AdminConfig.isFoundationAdmin(user.email)) return;

    final token = await user.getIdToken();

    for (final endpoint in _ensurePlatformAdminEndpointUrls()) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        if (response.statusCode >= 200 && response.statusCode < 300) return;
      } catch (_) {
        // Try next endpoint, then fall back to direct write.
      }
    }

    await _registerLocally(user.uid, user.email!);
  }

  Future<void> _registerLocally(String uid, String email) async {
    final snap = await _platformAdmins.doc(uid).get();
    if (snap.exists) return;
    await _platformAdmins.doc(uid).set(
      PlatformAdmin(uid: uid, email: email.trim().toLowerCase(), registeredAt: DateTime.now())
          .toMap(),
    );
  }

  List<String> _ensurePlatformAdminEndpointUrls() {
    final urls = <String>{
      AppConfig.ensurePlatformAdminApiUrl,
      AppConfig.ensurePlatformAdminFunctionUrl,
      '${AppConfig.productionWebOrigin}/ensurePlatformAdmin',
      '${AppConfig.productionWebOrigin}/api/ensurePlatformAdmin',
    };

    if (kIsWeb) {
      final origin = Uri.base.origin;
      urls.add('$origin/ensurePlatformAdmin');
      urls.add('$origin/api/ensurePlatformAdmin');
    }

    return urls.toList();
  }
}

/// Bulk provisioning via Cloud Function.
class UserProvisioningService {
  UserProvisioningService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<ProvisionUsersResult> provisionUsers({
    required String orgId,
    required List<ProvisionUserEntry> users,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Sign in required.');

    final token = await user.getIdToken();
    String? lastError;

    for (final endpoint in _provisionEndpointUrls()) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'orgId': orgId,
            'users': users.map((u) => u.toJson()).toList(),
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          return ProvisionUsersResult.fromJson(decoded);
        }

        lastError = _formatHttpFailure(
          endpoint: endpoint,
          statusCode: response.statusCode,
          body: response.body,
        );
        debugPrint('UserProvisioningService: $lastError');

        // Retry only when the HTTP route itself was missing (empty/HTML 404).
        if (response.statusCode == 404 && _isMissingRoute(response.body)) {
          continue;
        }
        break;
      } catch (e) {
        lastError = '$endpoint → $e';
        debugPrint('UserProvisioningService: $lastError');
      }
    }

    throw Exception(
      lastError ??
          'Bulk provisioning could not reach provisionInstitutionalUsers. '
          'Deploy with: firebase deploy --only functions,hosting',
    );
  }

  List<String> _provisionEndpointUrls() {
    final urls = <String>{
      AppConfig.provisionInstitutionalUsersApiUrl,
      AppConfig.provisionInstitutionalUsersFunctionUrl,
      '${AppConfig.productionWebOrigin}/provisionInstitutionalUsers',
      '${AppConfig.productionWebOrigin}/api/provisionInstitutionalUsers',
    };

    if (kIsWeb) {
      final origin = Uri.base.origin;
      urls.add('$origin/provisionInstitutionalUsers');
      urls.add('$origin/api/provisionInstitutionalUsers');
    }

    return urls.toList();
  }

  String _formatHttpFailure({
    required String endpoint,
    required int statusCode,
    required String body,
  }) {
    final trimmed = body.trim();
    if (trimmed.isNotEmpty) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final error = decoded['error'] as String?;
          if (error != null && error.isNotEmpty) {
            return error;
          }
        }
      } catch (_) {
        // Fall through to raw body.
      }
      return trimmed;
    }

    if (statusCode == 404) {
      return 'Provisioning API not found at $endpoint (HTTP 404). '
          'Local web dev cannot use hosting rewrites — the app will call the '
          'deployed Cloud Function directly. If this persists, deploy with: '
          'firebase deploy --only functions,hosting';
    }

    return 'Bulk provisioning failed at $endpoint (HTTP $statusCode).';
  }

  bool _isMissingRoute(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return true;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> && decoded.containsKey('error')) {
        return false;
      }
    } catch (_) {
      // Not JSON — likely an HTML error page from a dev server or CDN.
    }
    return trimmed.startsWith('<!') || trimmed.toLowerCase().contains('<html');
  }
}

class ProvisionUserEntry {
  const ProvisionUserEntry({required this.email, this.displayName});

  final String email;
  final String? displayName;

  Map<String, dynamic> toJson() => {
        'email': email.trim().toLowerCase(),
        if (displayName != null && displayName!.trim().isNotEmpty)
          'displayName': displayName!.trim(),
      };
}

class ProvisionUsersResult {
  const ProvisionUsersResult({
    required this.created,
    required this.skipped,
  });

  final List<ProvisionedAccount> created;
  final List<String> skipped;

  factory ProvisionUsersResult.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created'] as List<dynamic>? ?? const [];
    return ProvisionUsersResult(
      created: createdRaw
          .map((e) => ProvisionedAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
      skipped: (json['skipped'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class ProvisionedAccount {
  const ProvisionedAccount({
    required this.email,
    required this.temporaryPassword,
    this.displayName,
    this.welcomeEmailSent = false,
    this.welcomeEmailError,
  });

  final String email;
  final String temporaryPassword;
  final String? displayName;
  final bool welcomeEmailSent;
  final String? welcomeEmailError;

  factory ProvisionedAccount.fromJson(Map<String, dynamic> json) {
    return ProvisionedAccount(
      email: json['email'] as String? ?? '',
      temporaryPassword: json['temporaryPassword'] as String? ?? '',
      displayName: json['displayName'] as String?,
      welcomeEmailSent: json['welcomeEmailSent'] as bool? ?? false,
      welcomeEmailError: json['welcomeEmailError'] as String?,
    );
  }
}
