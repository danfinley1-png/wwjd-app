import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../models/shared_reflection.dart';
import '../app_links.dart';
import '../content_guidance/content_guidance_models.dart';
import '../content_guidance/shared_content_gate.dart';
import '../gift_share_payload.dart';

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
    Map<String, dynamic>? extraFields,
  }) async {
    final personalNote = extraFields?['personalNote']?.toString();

    final prepared = sharedContentGate.processSilently(
      SharedContentInput(
        question: question,
        response: response,
        title: title,
        personalNote: personalNote,
      ),
      channel: SharedContentChannel.shareLink,
    );
    final sanitized = prepared.input;

    final id = _generateShareId();
    final data = <String, dynamic>{
      'question': (sanitized.question ?? question).trim(),
      'response': (sanitized.response ?? response).trim(),
      'title': ((sanitized.title ?? title)?.trim().isNotEmpty == true)
          ? (sanitized.title ?? title)!.trim()
          : 'Shared Reflection',
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (extraFields != null) {
      extraFields.remove('createdAt');
      final revisedNote = sanitized.personalNote ?? personalNote;
      final merged = Map<String, dynamic>.from(extraFields);
      if (revisedNote != null) {
        merged['personalNote'] = revisedNote.trim().isEmpty ? null : revisedNote.trim();
      }
      if (prepared.requiresAnonymousSharing) {
        merged['shareAnonymously'] = true;
        merged['sharedByDisplayName'] = null;
        merged['favoriteSaint'] = null;
      }
      data.addAll(merged);
    }
    await _shares.doc(id).set(data);
    return id;
  }

  /// Creates a branded gift / Kingdom Challenge share link.
  Future<String> createGiftShare({
    required GiftSharePayload payload,
    String? createdByUid,
  }) async {
    final doc = payload.toShareDocument(createdByUid: createdByUid);
    return createShare(
      question: doc['question'] as String,
      response: doc['response'] as String,
      title: doc['title'] as String,
      createdByUid: createdByUid,
      extraFields: doc,
    );
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

  String _shareBaseOrigin() => AppLinks.baseOrigin();

  String _generateShareId() {
    return const Uuid().v4().replaceAll('-', '').substring(0, 12);
  }
}
