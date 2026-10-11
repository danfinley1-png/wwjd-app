import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;

import '../../models/saint_video.dart';
import '../config.dart';

/// Reads and writes saint video metadata. Clip files stay in Storage.
class SaintsService {
  SaintsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? _storageForApp();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  static const int maxVideoBytes = 12 * 1024 * 1024;

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

  static bool get _useUploadProxy {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(SaintEntry.collectionName);

  Stream<List<SaintEntry>> watchPublished() {
    return _col
        .where('status', isEqualTo: SaintPublishStatus.published.firestoreValue)
        .orderBy('name')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => SaintEntry.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<SaintEntry>> watchAll() {
    return _col.orderBy('name').snapshots().map((snap) =>
        snap.docs.map((doc) => SaintEntry.fromMap(doc.id, doc.data())).toList());
  }

  Stream<SaintEntry?> watchById(String saintId) {
    if (saintId.isEmpty) return Stream.value(null);
    return _col.doc(saintId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return SaintEntry.fromMap(snap.id, snap.data()!);
    });
  }

  Future<SaintEntry?> getById(String saintId) async {
    final snap = await _col.doc(saintId).get();
    if (!snap.exists || snap.data() == null) return null;
    return SaintEntry.fromMap(snap.id, snap.data()!);
  }

  Future<String> createDraft({
    required String name,
    String feastDay = '',
    String summary = '',
  }) async {
    final user = _requireSignedIn();
    final id = SaintEntry.slugify(name);
    final existing = await _col.doc(id).get();
    if (existing.exists) {
      throw StateError('A saint entry with this name already exists.');
    }
    final entry = SaintEntry.draft(
      id: id,
      name: name,
      feastDay: feastDay,
      summary: summary,
    );
    await _col.doc(id).set(
          entry.toMap(updatedByUid: user.uid, createdByUid: user.uid),
        );
    return id;
  }

  Future<void> saveMetadata(SaintEntry entry) async {
    final user = _requireSignedIn();
    if (entry.name.trim().isEmpty) {
      throw ArgumentError('Name is required.');
    }
    await _col.doc(entry.id).set(
          entry.toMap(updatedByUid: user.uid),
          SetOptions(merge: true),
        );
  }

  Future<void> publish(SaintEntry entry) async {
    final user = _requireSignedIn();
    if (!entry.canPublish) {
      throw StateError(
        'Upload all ${SaintSegment.count} clips before publishing.',
      );
    }
    await _col.doc(entry.id).set(
          entry.toMap(updatedByUid: user.uid, publishing: true),
          SetOptions(merge: true),
        );
  }

  Future<void> unpublish(SaintEntry entry) async {
    final user = _requireSignedIn();
    await _col.doc(entry.id).set(
          entry.toMap(updatedByUid: user.uid, unpublishing: true),
          SetOptions(merge: true),
        );
  }

  Future<SaintEntry> uploadSegmentMp4({
    required SaintEntry entry,
    required int order,
    required Uint8List bytes,
    String fileName = 'clip.mp4',
  }) async {
    _requireSignedIn();
    if (order < 1 || order > SaintSegment.count) {
      throw ArgumentError('Segment order must be 1–${SaintSegment.count}.');
    }
    if (bytes.isEmpty) {
      throw ArgumentError('The selected file was empty.');
    }
    if (bytes.length > maxVideoBytes) {
      throw ArgumentError('Each clip must be under 12 MB.');
    }
    if (!fileName.toLowerCase().endsWith('.mp4')) {
      throw ArgumentError('Upload an .mp4 file.');
    }

    final downloadUrl = _useUploadProxy
        ? await _uploadViaProxy(saintId: entry.id, order: order, bytes: bytes)
        : await _uploadDirect(saintId: entry.id, order: order, bytes: bytes);

    final next = [
      for (final segment in entry.segments)
        if (segment.order == order)
          segment.copyWith(videoUrl: downloadUrl)
        else
          segment,
    ];
    final updated = entry.copyWith(segments: next);
    await saveMetadata(updated);
    return updated;
  }

  Future<Uint8List?> pickMp4Bytes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw ArgumentError(
        'Could not read that file. Choose an .mp4 under 12 MB.',
      );
    }
    if (!file.name.toLowerCase().endsWith('.mp4')) {
      throw ArgumentError('Upload an .mp4 file.');
    }
    return bytes;
  }

  Future<String> _uploadDirect({
    required String saintId,
    required int order,
    required Uint8List bytes,
  }) async {
    final path = SaintEntry.storageObjectPath(saintId, order);
    final ref = _storage.ref().child(path);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'video/mp4',
        cacheControl: 'public,max-age=3600',
      ),
    );
    return ref.getDownloadURL();
  }

  Future<String> _uploadViaProxy({
    required String saintId,
    required int order,
    required Uint8List bytes,
  }) async {
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Sign in again, then retry the upload.');
    }
    final response = await http
        .post(
          Uri.parse(AppConfig.saintVideoApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'saintId': saintId,
            'order': order,
            'contentType': 'video/mp4',
            'dataBase64': base64Encode(bytes),
          }),
        )
        .timeout(const Duration(seconds: 180));

    final body = response.body.trim();
    if (response.statusCode != 200) {
      var detail = body;
      try {
        final parsed = jsonDecode(body);
        if (parsed is Map && parsed['error'] != null) {
          detail = parsed['error'].toString();
        }
      } catch (_) {}
      throw StateError(detail.isEmpty ? 'Upload failed.' : detail);
    }
    final parsed = jsonDecode(body);
    if (parsed is Map && parsed['downloadUrl'] is String) {
      return parsed['downloadUrl'] as String;
    }
    throw StateError('Upload did not return a video URL.');
  }

  User _requireSignedIn() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to manage Saints videos.');
    }
    return user;
  }
}
