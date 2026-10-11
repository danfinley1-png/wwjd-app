import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/platform_admin_claim.dart';
import '../config/admin_config.dart';

/// Platform-level (Super / Overall) administrator operations.
class PlatformAdminService {
  PlatformAdminService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  bool get isFoundationAdminEmail {
    return AdminConfig.isFoundationAdmin(_auth.currentUser?.email);
  }

  Stream<bool> watchIsSuperAdmin() {
    return PlatformAdminClaim.watchPlatformAdmin(_auth);
  }

  Future<bool> isSuperAdmin() async {
    return PlatformAdminClaim.isPlatformAdmin(_auth);
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
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await user.getIdToken(true);
          return;
        }
      } catch (_) {
        // Try next endpoint.
      }
    }

    debugPrint(
      'PlatformAdminService.ensureRegistered: Cloud Function unavailable. '
      'Deploy functions and call ensurePlatformAdmin to set admin claim.',
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

  Future<BulkRosterResult> provisionUsers({
    String? orgId,
    String target = 'organization',
    required List<ProvisionUserEntry> users,
    required String mode,
    List<String> groupIds = const [],
    bool attachOrgInvite = true,
    String? emailSubject,
    String? emailText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Sign in required.');

    final isPlatform = target == 'platform' || target == 'wwjd-di';
    final trimmedOrgId = orgId?.trim() ?? '';
    if (!isPlatform && trimmedOrgId.isEmpty) {
      throw Exception('Organization is required unless inviting to WWJD-DI only.');
    }

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
            'target': isPlatform ? 'platform' : 'organization',
            if (!isPlatform) 'orgId': trimmedOrgId,
            'mode': mode,
            'users': users.map((u) => u.toJson()).toList(),
            'groupIds': isPlatform ? const <String>[] : groupIds,
            'attachOrgInvite': isPlatform ? false : attachOrgInvite,
            if (emailSubject != null && emailSubject.trim().isNotEmpty)
              'emailSubject': emailSubject.trim(),
            if (emailText != null && emailText.trim().isNotEmpty)
              'emailText': emailText.trim(),
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          return BulkRosterResult.fromJson(decoded);
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

class BulkRosterResult {
  const BulkRosterResult({
    required this.mode,
    required this.rows,
  });

  final String mode;
  final List<BulkRosterRow> rows;

  factory BulkRosterResult.fromJson(Map<String, dynamic> json) {
    final rowsRaw = json['rows'] as List<dynamic>? ?? const [];
    return BulkRosterResult(
      mode: json['mode'] as String? ?? '',
      rows: rowsRaw
          .map((e) => BulkRosterRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BulkRosterRow {
  const BulkRosterRow({
    required this.email,
    this.displayName,
    this.created = false,
    this.invited = false,
    this.emailSent = false,
    this.emailFailed = false,
    this.emailError,
    this.skipped = false,
    this.skipReason,
    this.temporaryPassword,
  });

  final String email;
  final String? displayName;
  final bool created;
  final bool invited;
  final bool emailSent;
  final bool emailFailed;
  final String? emailError;
  final bool skipped;
  final String? skipReason;
  final String? temporaryPassword;

  String get skipLabel {
    switch (skipReason) {
      case 'already_exists':
        return 'Already has an account';
      case 'already_invited':
        return 'Pending invite already exists';
      case 'already_member':
        return 'Already a member';
      case 'invalid':
        return 'Invalid email';
      case 'error':
        return emailError ?? 'Could not complete';
      default:
        return skipped ? 'Skipped' : '';
    }
  }

  factory BulkRosterRow.fromJson(Map<String, dynamic> json) {
    return BulkRosterRow(
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      created: json['created'] as bool? ?? false,
      invited: json['invited'] as bool? ?? false,
      emailSent: json['emailSent'] as bool? ?? false,
      emailFailed: json['emailFailed'] as bool? ?? false,
      emailError: json['emailError'] as String?,
      skipped: json['skipped'] as bool? ?? false,
      skipReason: json['skipReason'] as String?,
      temporaryPassword: json['temporaryPassword'] as String?,
    );
  }
}
