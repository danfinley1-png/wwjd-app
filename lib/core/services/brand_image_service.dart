import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'profile_photo_service.dart';

/// Shared loader for organization / group brand images.
///
/// Flutter [NetworkImage] blanks on web CORS. Download-token URLs also go
/// stale after a re-upload. This service loads `organizations/{orgId}/logo.jpg`
/// by path: Cloud Function proxy on web, Storage SDK on native, with one
/// in-memory cache for every [GroupBrandMark] on screen.
class BrandImageService {
  BrandImageService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? _storageForApp();

  static final BrandImageService instance = BrandImageService();

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  static final Map<String, Uint8List> _bytes = {};
  static final Map<String, Future<Uint8List?>> _inflight = {};

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

  static String logoObjectPath(String orgId) =>
      'organizations/${orgId.trim()}/logo.jpg';

  /// Cache key: prefer org id so a new download token still hits the same file.
  static String cacheKey({String? orgId, String? url}) {
    final id = orgId?.trim();
    if (id != null && id.isNotEmpty) return 'org:$id';
    final trimmed = url?.trim() ?? '';
    final parsed = orgIdFromLogoUrl(trimmed);
    if (parsed != null) return 'org:$parsed';
    return 'url:${ProfilePhotoService.stripCacheBuster(trimmed)}';
  }

  static String? orgIdFromLogoUrl(String url) {
    final path = objectPathFromUrl(url);
    if (path == null) return null;
    final match = RegExp(
      r'^organizations/([^/]+)/logo\.jpg$',
      caseSensitive: false,
    ).firstMatch(path);
    return match?.group(1);
  }

  static String? objectPathFromUrl(String raw) {
    final url = ProfilePhotoService.stripCacheBuster(raw.trim());
    if (url.isEmpty) return null;
    if (url.startsWith('gs://')) {
      final rest = url.substring(5);
      final slash = rest.indexOf('/');
      if (slash < 0 || slash == rest.length - 1) return null;
      return rest.substring(slash + 1);
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final oIndex = segments.indexOf('o');
    if (oIndex >= 0 && oIndex < segments.length - 1) {
      return Uri.decodeComponent(segments.sublist(oIndex + 1).join('/'));
    }
    if (uri.host.contains('storage.googleapis.com') && segments.length >= 2) {
      return segments.sublist(1).join('/');
    }
    return null;
  }

  Uint8List? cachedBytes({String? orgId, String? url}) {
    return _bytes[cacheKey(orgId: orgId, url: url)];
  }

  void putOrgLogo(String orgId, Uint8List bytes) {
    if (orgId.trim().isEmpty || bytes.isEmpty) return;
    final key = cacheKey(orgId: orgId);
    _inflight.remove(key);
    _bytes[key] = bytes;
  }

  void evictOrg(String orgId) {
    _bytes.remove(cacheKey(orgId: orgId));
    _inflight.remove(cacheKey(orgId: orgId));
  }

  Future<Uint8List?> load({String? orgId, String? url}) {
    final key = cacheKey(orgId: orgId, url: url);
    final hit = _bytes[key];
    if (hit != null && hit.isNotEmpty) return Future.value(hit);

    return _inflight.putIfAbsent(key, () async {
      try {
        final bytes = await _fetch(orgId: orgId, url: url);
        if (bytes != null && bytes.isNotEmpty) {
          _bytes[key] = bytes;
        }
        return bytes;
      } finally {
        _inflight.remove(key);
      }
    });
  }

  Future<Uint8List?> _fetch({String? orgId, String? url}) async {
    final resolvedOrgId = (orgId != null && orgId.trim().isNotEmpty)
        ? orgId.trim()
        : orgIdFromLogoUrl(url ?? '');
    final path = resolvedOrgId != null
        ? logoObjectPath(resolvedOrgId)
        : objectPathFromUrl(url ?? '');

    if (resolvedOrgId != null) {
      final fromProxy = await _loadViaOrgLogoProxy(resolvedOrgId);
      if (fromProxy != null && fromProxy.isNotEmpty) return fromProxy;
    }

    // Web Storage SDK / NetworkImage hits CORS. Stay on the Function proxy.
    if (kIsWeb) return null;

    if (path != null && path.isNotEmpty) {
      final fromPath = await _loadViaStoragePath(path);
      if (fromPath != null && fromPath.isNotEmpty) return fromPath;
    }

    final trimmedUrl = url?.trim();
    if (trimmedUrl != null &&
        trimmedUrl.isNotEmpty &&
        ProfilePhotoService.isFirebaseStorageUrl(trimmedUrl)) {
      final fromRef = await ProfilePhotoService().loadBytesForStorageUrl(
        trimmedUrl,
      );
      if (fromRef != null && fromRef.isNotEmpty) return fromRef;
    }

    if (trimmedUrl != null && trimmedUrl.startsWith('http')) {
      try {
        final response = await http
            .get(Uri.parse(ProfilePhotoService.stripCacheBuster(trimmedUrl)))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      } catch (e) {
        debugPrint('BrandImageService http: $e');
      }
    }

    return null;
  }

  Future<Uint8List?> _loadViaOrgLogoProxy(String orgId) async {
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) return null;
    try {
      final uri = Uri.parse(AppConfig.orgLogoApiUrl).replace(
        queryParameters: {'orgId': orgId},
      );
      final response = await http
          .get(
            uri,
            headers: {'Authorization': 'Bearer $idToken'},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 404) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'BrandImageService proxy ${response.statusCode} ${response.body}',
        );
        return null;
      }
      if (response.bodyBytes.isEmpty) return null;
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('application/json')) return null;
      return response.bodyBytes;
    } catch (e) {
      debugPrint('BrandImageService proxy: $e');
      return null;
    }
  }

  Future<Uint8List?> _loadViaStoragePath(String path) async {
    try {
      final bytes = await _storage.ref().child(path).getData(
            ProfilePhotoService.maxBytes,
          );
      if (bytes != null && bytes.isNotEmpty) return bytes;
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found' && e.code != 'unauthorized') {
        debugPrint('BrandImageService storage ${e.code}: ${e.message}');
      }
    } catch (e) {
      debugPrint('BrandImageService storage: $e');
    }
    return null;
  }
}
