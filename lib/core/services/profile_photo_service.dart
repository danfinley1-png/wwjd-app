import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config.dart';

/// Uploads and removes profile photos in Firebase Storage.
class ProfilePhotoService {
  ProfilePhotoService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? _storageForApp(),
        _picker = picker ?? ImagePicker();

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  static const int maxBytes = 5 * 1024 * 1024;

  static FirebaseStorage _storageForApp() {
    var bucket = Firebase.app().options.storageBucket?.trim();
    if (bucket == null || bucket.isEmpty) {
      bucket = AppConfig.firebaseStorageBucket;
    }
    if (bucket.startsWith('gs://')) {
      bucket = bucket.substring(5);
    }
    return FirebaseStorage.instanceFor(
      app: Firebase.app(),
      bucket: bucket,
    );
  }

  static String get storageBucketName {
    final fromOptions = Firebase.app().options.storageBucket?.trim();
    if (fromOptions != null && fromOptions.isNotEmpty) {
      return fromOptions.startsWith('gs://')
          ? fromOptions.substring(5)
          : fromOptions;
    }
    return AppConfig.firebaseStorageBucket;
  }

  static String storagePathForUid(String uid) => 'users/$uid/profile.jpg';

  /// Web and desktop hit Storage CORS/network limits — upload via Cloud Function.
  static bool get _useUploadProxy {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Reference? _profileRef(String uid) {
    return _storage.ref().child(storagePathForUid(uid));
  }

  static bool isFirebaseStorageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('gs://') ||
        url.contains('firebasestorage.googleapis.com') ||
        url.contains('storage.googleapis.com');
  }

  static String? displayUrl(String? photoUrl, {int? cacheBustMs}) {
    final trimmed = photoUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (cacheBustMs == null) return trimmed;
    final separator = trimmed.contains('?') ? '&' : '?';
    return '$trimmed${separator}v=$cacheBustMs';
  }

  static String stripCacheBuster(String photoUrl) {
    final uri = Uri.tryParse(photoUrl.trim());
    if (uri == null) return photoUrl.trim();
    if (!uri.queryParameters.containsKey('v')) return photoUrl.trim();
    final cleaned = Map<String, String>.from(uri.queryParameters)..remove('v');
    return uri.replace(queryParameters: cleaned.isEmpty ? null : cleaned).toString();
  }

  Future<Uint8List?> loadBytesForCurrentUser() async {
    if (kIsWeb) {
      return loadBytesViaWebProxy();
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      return await _profileRef(uid)?.getData(maxBytes);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return null;
      rethrow;
    }
  }

  /// Loads profile photo bytes through the CORS-enabled Cloud Function (web / iOS Safari).
  Future<Uint8List?> loadBytesViaWebProxy() async {
    if (!kIsWeb) return null;
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) return null;

    late final http.Response response;
    try {
      response = await http
          .get(
            Uri.parse(AppConfig.profilePhotoApiUrl),
            headers: {'Authorization': 'Bearer $idToken'},
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      return null;
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    if (response.bodyBytes.isEmpty) return null;
    return response.bodyBytes;
  }

  Future<String?> getDownloadUrlForCurrentUser() async {
    if (kIsWeb) return null;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      return await _profileRef(uid)?.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return null;
      rethrow;
    }
  }

  Future<Uint8List?> loadProfileBytes({String? photoUrl}) async {
    if (kIsWeb) {
      final fromProxy = await loadBytesViaWebProxy();
      if (fromProxy != null && fromProxy.isNotEmpty) return fromProxy;
    }

    final fromPath = await loadBytesForCurrentUser();
    if (fromPath != null && fromPath.isNotEmpty) return fromPath;

    final trimmed = photoUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return loadBytesForUrl(trimmed);
  }

  Future<Uint8List?> loadBytesForUrl(String photoUrl) async {
    return loadBytesForStorageUrl(photoUrl);
  }

  /// Loads any Firebase Storage object by download URL (org logos, profiles).
  /// Uses the Storage SDK so web CORS does not blank [NetworkImage].
  Future<Uint8List?> loadBytesForStorageUrl(String url) async {
    final trimmed = stripCacheBuster(url.trim());
    if (trimmed.isEmpty) return null;
    try {
      final ref = _storage.refFromURL(trimmed);
      return await ref.getData(maxBytes);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found' || e.code == 'unauthorized') {
        return null;
      }
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<String?> pickAndUpload({ImageSource source = ImageSource.gallery}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to add a profile photo.');
    }
    if (user.isAnonymous) {
      throw Exception(
        'Create an account (not guest) to save a profile photo.',
      );
    }

    final picked = await _pickImageBytes(source);
    if (picked == null) return null;

    return uploadPicked(picked.toProfilePhotoPick());
  }

  /// Web/Edge: pick via [file_picker] (reliable; HtmlElementView callbacks often fail).
  Future<ProfilePhotoPick?> pickGalleryViaFilePicker() async {
    if (!kIsWeb) {
      throw StateError('pickGalleryViaFilePicker is only available on web.');
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception(
        'Could not read the selected image. Try a JPG or PNG under 5 MB.',
      );
    }

    final name = file.name.isNotEmpty ? file.name : 'photo.jpg';
    return ProfilePhotoPick(
      bytes: bytes,
      contentType: _contentTypeForPath(name),
      name: name,
    );
  }

  /// @deprecated Use [pickGalleryViaFilePicker] on web.
  Future<ProfilePhotoPick?> beginWebGalleryPick() => pickGalleryViaFilePicker();

  Future<String?> uploadPicked(ProfilePhotoPick picked) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to add a profile photo.');
    }
    if (user.isAnonymous) {
      throw Exception(
        'Create an account (not guest) to save a profile photo.',
      );
    }

    if (picked.bytes.isEmpty) {
      throw Exception('Could not read the selected image. Try a JPG or PNG file.');
    }
    if (picked.bytes.length > maxBytes) {
      throw Exception('Photo is too large. Please choose an image under 5 MB.');
    }

    final uid = user.uid;
    final ref = _profileRef(uid)!;

    try {
      if (_useUploadProxy) {
        return await _uploadViaWebProxy(
          bytes: picked.bytes,
          contentType: picked.contentType,
        );
      }

      await ref.putData(
        picked.bytes,
        SettableMetadata(
          contentType: picked.contentType,
          cacheControl: 'public,max-age=3600',
        ),
      );
      await ref.getMetadata();
    } on FirebaseException catch (e) {
      throw _uploadException(e);
    } catch (e) {
      throw _wrapUploadError(e);
    }

    try {
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw _uploadException(e);
    } catch (e) {
      throw _wrapUploadError(e);
    }
  }

  /// Web/Edge: upload through Cloud Function (same-origin or CORS-enabled proxy).
  Future<String> _uploadViaWebProxy({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Sign in again, then retry your profile photo upload.');
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(AppConfig.profilePhotoApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'contentType': contentType,
              'dataBase64': base64Encode(bytes),
            }),
          )
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      throw _wrapUploadError(e);
    }

    final body = response.body.trim();
    if (body.startsWith('<!DOCTYPE') ||
        body.startsWith('<html') ||
        body.startsWith('<!doctype')) {
      throw Exception(
        'Profile photo upload service returned an invalid response. '
        'Hard-refresh the page and try again.',
      );
    }
    if (response.statusCode != 200) {
      String detail = body;
      try {
        final parsed = jsonDecode(body);
        if (parsed is Map && parsed['error'] != null) {
          detail = parsed['error'].toString();
        }
      } catch (_) {}
      if (response.statusCode == 404 || body.startsWith('<!DOCTYPE')) {
        throw Exception(
          'Profile photo upload service is not deployed yet.\n\n'
          'Run from the project folder:\n'
          'firebase deploy --only functions\n\n'
          'Then hard-refresh Edge and try again.',
        );
      }
      throw Exception(detail);
    }

    try {
      final parsed = jsonDecode(body) as Map<String, dynamic>;
      final url = parsed['downloadUrl']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('Upload succeeded but no photo URL was returned.');
      }
      return url;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Invalid upload response: $body');
    }
  }

  /// On web, prefer [pickGalleryViaFilePicker].
  Future<_PickedImageBytes?> _pickImageBytes(ImageSource source) async {
    try {
      if (kIsWeb && source == ImageSource.gallery) {
        final picked = await pickGalleryViaFilePicker();
        if (picked == null) return null;
        return _PickedImageBytes(
          bytes: picked.bytes,
          contentType: picked.contentType,
          name: picked.name,
        );
      }

      final picked = await _picker.pickImage(
        source: source,
        maxWidth: kIsWeb ? null : 512,
        maxHeight: kIsWeb ? null : 512,
        imageQuality: kIsWeb ? null : 85,
      );
      if (picked == null) return null;

      final bytes = await picked.readAsBytes();
      return _PickedImageBytes(
        bytes: bytes,
        contentType: _contentTypeForPath(picked.name),
        name: picked.name,
      );
    } catch (e) {
      throw _wrapPickError(e);
    }
  }

  Exception _wrapPickError(Object e) {
    final message = e.toString().toLowerCase();
    if (message.contains('failed to fetch') ||
        message.contains('networkerror')) {
      return Exception(
        'Could not read the selected image in the browser. '
        'Try a JPG or PNG under 5 MB, or use Chrome/Edge.',
      );
    }
    return Exception('Could not open photo: $e');
  }

  Exception _wrapUploadError(Object e) {
    final message = e.toString().toLowerCase();
    if (message.contains('failed to fetch') ||
        message.contains('networkerror') ||
        message.contains('network error') ||
        message.contains('connection refused') ||
        message.contains('timeout')) {
      return Exception(
        'Could not reach the photo upload service. '
        'Check your internet connection, sign in again, and retry. '
        'If this keeps happening, hard-refresh the page (Ctrl+Shift+R).',
      );
    }
    return Exception('Upload failed: $e');
  }

  Exception _uploadException(FirebaseException e) {
    if (e.code == 'unauthorized' || e.code == 'permission-denied') {
      return Exception(
        'Storage upload blocked (${e.code}). '
        'Run: firebase deploy --only storage. '
        'On localhost web, also apply storage.cors.json to your Storage bucket.',
      );
    }
    if (e.code == 'unauthenticated') {
      return Exception('Sign in again, then retry your profile photo upload.');
    }
    return Exception('Upload failed (${e.code}): ${e.message ?? e}');
  }

  Future<void> deleteStoredPhoto() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _profileRef(uid)?.delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  static String _contentTypeForPath(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.jp')) {
      return 'image/jpeg';
    }
    return 'image/jpeg';
  }

  static bool get supportsCamera => !kIsWeb;
}

class _PickedImageBytes {
  const _PickedImageBytes({
    required this.bytes,
    required this.contentType,
    required this.name,
  });

  final Uint8List bytes;
  final String contentType;
  final String name;

  ProfilePhotoPick toProfilePhotoPick() => ProfilePhotoPick(
        bytes: bytes,
        contentType: contentType,
        name: name,
      );
}

/// Bytes picked for a profile photo upload.
class ProfilePhotoPick {
  const ProfilePhotoPick({
    required this.bytes,
    required this.contentType,
    required this.name,
  });

  final Uint8List bytes;
  final String contentType;
  final String name;
}
