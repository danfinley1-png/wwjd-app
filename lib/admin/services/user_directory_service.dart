import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../models/user_directory.dart';

/// Overall Admin directory of registered accounts and pending invites.
/// Never returns Seeking God's Wisdom, Reflections, or personal Gifts.
class UserDirectoryService {
  UserDirectoryService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<UserDirectory> fetchDirectory() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Sign in required.');

    final token = await user.getIdToken();
    String? lastError;

    for (final endpoint in _directoryEndpointUrls()) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: '{}',
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          return UserDirectory.fromJson(decoded);
        }

        lastError = _formatFailure(endpoint, response.statusCode, response.body);
        debugPrint('UserDirectoryService: $lastError');
        if (response.statusCode == 404 && _isMissingRoute(response.body)) {
          continue;
        }
        break;
      } catch (e) {
        lastError = '$endpoint → $e';
        debugPrint('UserDirectoryService: $lastError');
      }
    }

    throw Exception(
      lastError ??
          'User directory could not reach getUserDirectory. '
              'Deploy with: firebase deploy --only functions,hosting',
    );
  }

  Future<void> resendInvite({
    required String kind,
    required String inviteId,
    String? orgId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Sign in required.');

    final token = await user.getIdToken();
    String? lastError;

    for (final endpoint in _resendEndpointUrls()) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'kind': kind,
            'inviteId': inviteId,
            if (orgId != null && orgId.isNotEmpty) 'orgId': orgId,
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['ok'] == false) {
            throw Exception(
              decoded['error']?.toString() ?? 'Invitation email failed to send.',
            );
          }
          return;
        }

        lastError = _formatFailure(endpoint, response.statusCode, response.body);
        debugPrint('UserDirectoryService resend: $lastError');
        if (response.statusCode == 404 && _isMissingRoute(response.body)) {
          continue;
        }
        break;
      } catch (e) {
        if (e is Exception && e.toString().contains('Invitation email')) rethrow;
        lastError = '$endpoint → $e';
        debugPrint('UserDirectoryService resend: $lastError');
      }
    }

    throw Exception(lastError ?? 'Could not resend invitation.');
  }

  List<String> _directoryEndpointUrls() {
    final urls = <String>{
      AppConfig.userDirectoryApiUrl,
      AppConfig.userDirectoryFunctionUrl,
      '${AppConfig.productionWebOrigin}/api/getUserDirectory',
      '${AppConfig.productionWebOrigin}/getUserDirectory',
    };
    if (kIsWeb) {
      final origin = Uri.base.origin;
      urls.add('$origin/api/getUserDirectory');
      urls.add('$origin/getUserDirectory');
    }
    return urls.toList();
  }

  List<String> _resendEndpointUrls() {
    final urls = <String>{
      AppConfig.resendDirectoryInviteApiUrl,
      AppConfig.resendDirectoryInviteFunctionUrl,
      '${AppConfig.productionWebOrigin}/api/resendDirectoryInvite',
      '${AppConfig.productionWebOrigin}/resendDirectoryInvite',
    };
    if (kIsWeb) {
      final origin = Uri.base.origin;
      urls.add('$origin/api/resendDirectoryInvite');
      urls.add('$origin/resendDirectoryInvite');
    }
    return urls.toList();
  }

  String _formatFailure(String endpoint, int statusCode, String body) {
    final trimmed = body.trim();
    if (trimmed.isNotEmpty) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final error = decoded['error'] as String?;
          if (error != null && error.isNotEmpty) return error;
        }
      } catch (_) {}
      return trimmed;
    }
    return '$endpoint → HTTP $statusCode';
  }

  bool _isMissingRoute(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return true;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> && decoded.containsKey('error')) {
        return false;
      }
    } catch (_) {}
    return trimmed.startsWith('<!') || trimmed.toLowerCase().contains('<html');
  }
}
