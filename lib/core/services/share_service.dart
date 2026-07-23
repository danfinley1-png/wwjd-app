import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import '../../models/shared_reflection.dart';
import '../config.dart';

class ShareService {
  ShareService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _shares =>
      _firestore.collection('shares');

  /// Creates a public share document and returns its id for deep links.
  Future<String> createShare({
    required String question,
    required String response,
    String? title,
    String? createdByUid,
  }) async {
    final id = _generateShareId();
    await _shares.doc(id).set({
      'question': question.trim(),
      'response': response.trim(),
      'title': (title?.trim().isNotEmpty == true)
          ? title!.trim()
          : 'Shared Reflection',
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  Future<SharedReflection?> getShare(String id) async {
    if (id.trim().isEmpty) return null;
    try {
      final snap = await _shares.doc(id.trim()).get();
      if (!snap.exists || snap.data() == null) return null;
      return SharedReflection.fromMap(snap.id, snap.data()!);
    } catch (e) {
      print('ShareService.getShare error: $e');
      rethrow;
    }
  }

  /// Clean shareable URL: `/s/{id}` (also supports `/share/{id}` via routing).
  String buildShareUrl(String shareId) {
    final base = _shareBaseOrigin();
    return '$base/s/$shareId';
  }

  String _shareBaseOrigin() {
    if (AppConfig.webBaseUrl != null && AppConfig.webBaseUrl!.isNotEmpty) {
      return AppConfig.webBaseUrl!.replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return 'https://wwjd.app';
  }

  String _generateShareId() {
    return const Uuid().v4().replaceAll('-', '').substring(0, 12);
  }
}
