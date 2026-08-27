import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/services/brand_image_service.dart';
import '../../core/services/profile_photo_service.dart';

/// Uploads one organization logo (inherited by groups and group Gifts).
class OrgLogoService {
  OrgLogoService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static const int maxBytes = ProfilePhotoService.maxBytes;

  Future<ProfilePhotoPick?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    Uint8List? bytes = file.bytes;
    if ((bytes == null || bytes.isEmpty) && !kIsWeb && file.path != null) {
      // Native file_picker may omit bytes unless withData succeeded.
      return null;
    }
    if (bytes == null || bytes.isEmpty) {
      throw Exception(
        'Could not read the selected image. Try a JPG or PNG under 5 MB.',
      );
    }
    final name = file.name.isNotEmpty ? file.name : 'logo.jpg';
    return ProfilePhotoPick(
      bytes: bytes,
      contentType: _contentTypeForPath(name),
      name: name,
    );
  }

  Future<String> uploadLogo({
    required String orgId,
    required ProfilePhotoPick picked,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw Exception('Sign in with an administrator account to set the logo.');
    }
    if (picked.bytes.isEmpty) {
      throw Exception('Could not read the selected image.');
    }
    if (picked.bytes.length > maxBytes) {
      throw Exception('Logo is too large. Please choose an image under 5 MB.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Sign in again, then retry the logo upload.');
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(AppConfig.orgLogoApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'orgId': orgId,
              'contentType': picked.contentType,
              'dataBase64': base64Encode(picked.bytes),
            }),
          )
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      throw Exception('Could not upload the organization logo: $e');
    }

    final body = response.body.trim();
    if (response.statusCode != 200) {
      String detail = body;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['error'] is String) {
          detail = decoded['error'] as String;
        }
      } catch (_) {}
      throw Exception(detail.isEmpty ? 'Could not upload the logo.' : detail);
    }

    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['downloadUrl'] is String) {
      BrandImageService.instance.putOrgLogo(orgId, picked.bytes);
      return decoded['downloadUrl'] as String;
    }
    throw Exception('Logo uploaded, but no image URL was returned.');
  }

  static String _contentTypeForPath(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
