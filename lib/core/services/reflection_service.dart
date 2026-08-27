import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:uuid/uuid.dart';



import '../../models/reflection_entry.dart';

import '../../models/reflection_source.dart';

import '../../models/reflection_thread.dart';



class ReflectionService {

  ReflectionService({

    FirebaseFirestore? firestore,

    FirebaseAuth? auth,

  })  : _firestore = firestore ?? FirebaseFirestore.instance,

        _auth = auth ?? FirebaseAuth.instance;



  final FirebaseFirestore _firestore;

  final FirebaseAuth _auth;



  static const _uuid = Uuid();



  CollectionReference<Map<String, dynamic>>? get _threadsCol {

    final uid = _auth.currentUser?.uid;

    if (uid == null) return null;

    return _firestore.collection('users').doc(uid).collection('reflections');

  }



  CollectionReference<Map<String, dynamic>>? _entriesCol(String threadId) {

    final threads = _threadsCol;

    if (threads == null) return null;

    return threads.doc(threadId).collection('entries');

  }



  Stream<List<ReflectionThread>> watchThreads() {

    final col = _threadsCol;

    if (col == null) return Stream.value([]);



    return col.orderBy('updatedAt', descending: true).snapshots().map((snap) {

      return snap.docs

          .map((doc) => ReflectionThread.fromMap(doc.id, doc.data()))

          .toList();

    });

  }



  Stream<ReflectionThread?> watchThread(String threadId) {

    final col = _threadsCol;

    if (col == null) return Stream.value(null);



    return col.doc(threadId).snapshots().map((snap) {

      if (!snap.exists || snap.data() == null) return null;

      return ReflectionThread.fromMap(snap.id, snap.data()!);

    });

  }



  Stream<List<ReflectionEntry>> watchEntries(String threadId) {

    final col = _entriesCol(threadId);

    if (col == null) return Stream.value([]);



    return col.orderBy('createdAt', descending: false).snapshots().map((snap) {

      return snap.docs

          .map((doc) => ReflectionEntry.fromMap(doc.id, doc.data()))

          .toList();

    });

  }



  Future<ReflectionThread?> findThreadForGift(String giftId) async {

    final col = _threadsCol;

    if (col == null) return null;



    final snap = await col

        .where('linkedGiftId', isEqualTo: giftId.trim())

        .limit(1)

        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;

    return ReflectionThread.fromMap(doc.id, doc.data());

  }



  Future<ReflectionThread?> findThreadForJourney(String journeyId) async {

    final col = _threadsCol;

    if (col == null) return null;



    final snap = await col

        .where('linkedJourneyId', isEqualTo: journeyId.trim())

        .limit(1)

        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;

    return ReflectionThread.fromMap(doc.id, doc.data());

  }



  Future<String?> latestEntryBodyForThread(String threadId) async {

    final entries = _entriesCol(threadId);

    if (entries == null) return null;



    final snap = await entries.orderBy('createdAt', descending: true).limit(1).get();

    if (snap.docs.isEmpty) return null;

    return snap.docs.first.data()['body']?.toString();

  }



  /// Creates a thread and its first entry. [body] is required; [title] is optional.

  Future<ReflectionThread> createReflection({

    String? title,

    required String body,

    String? linkedQuestionText,

    String? linkedResponseText,

    String? linkedGiftId,

    String? linkedJourneyId,

    String? linkedSourceTitle,

    String? source,

  }) async {

    final col = _threadsCol;

    final uid = _auth.currentUser?.uid;

    if (col == null || uid == null) {

      throw Exception('Sign in to save reflections.');

    }



    final trimmedBody = body.trim();

    if (trimmedBody.isEmpty) {

      throw Exception('Reflection text cannot be empty.');

    }



    final threadId = _uuid.v4();

    final entryId = _uuid.v4();

    final preview = _previewFor(trimmedBody);

    final batch = _firestore.batch();



    final threadRef = col.doc(threadId);

    batch.set(threadRef, {

      'title': title?.trim().isEmpty == true ? null : title?.trim(),

      'entryCount': 1,

      'lastEntryPreview': preview,

      'userId': uid,

      if (linkedQuestionText != null && linkedQuestionText.trim().isNotEmpty)

        'linkedQuestionText': linkedQuestionText.trim(),

      if (linkedResponseText != null && linkedResponseText.trim().isNotEmpty)

        'linkedResponseText': linkedResponseText.trim(),

      if (linkedGiftId != null && linkedGiftId.trim().isNotEmpty)

        'linkedGiftId': linkedGiftId.trim(),

      if (linkedJourneyId != null && linkedJourneyId.trim().isNotEmpty)

        'linkedJourneyId': linkedJourneyId.trim(),

      if (linkedSourceTitle != null && linkedSourceTitle.trim().isNotEmpty)

        'linkedSourceTitle': linkedSourceTitle.trim(),

      if (source != null && source.trim().isNotEmpty) 'source': source.trim(),

      'createdAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),

    });



    final entryRef = threadRef.collection('entries').doc(entryId);

    batch.set(entryRef, {

      'threadId': threadId,

      'body': trimmedBody,

      'createdAt': FieldValue.serverTimestamp(),

    });



    await batch.commit();



    return ReflectionThread(

      id: threadId,

      title: title?.trim(),

      entryCount: 1,

      lastEntryPreview: preview,

      userId: uid,

      linkedQuestionText: linkedQuestionText?.trim(),

      linkedResponseText: linkedResponseText?.trim(),

      linkedGiftId: linkedGiftId?.trim(),

      linkedJourneyId: linkedJourneyId?.trim(),

      linkedSourceTitle: linkedSourceTitle?.trim(),

      source: source?.trim(),

      createdAt: DateTime.now(),

      updatedAt: DateTime.now(),

    );

  }



  /// Keeps one private reflection thread per gift activity, updating the latest entry.

  Future<ReflectionThread?> upsertGiftReflection({

    required String giftId,

    required String giftTitle,

    required String body,

  }) async {

    final trimmedBody = body.trim();

    if (trimmedBody.isEmpty) return null;



    final existing = await findThreadForGift(giftId);

    if (existing != null) {

      await _updateLatestEntry(existing.id, trimmedBody);

      return existing.copyWith(

        lastEntryPreview: _previewFor(trimmedBody),

        updatedAt: DateTime.now(),

      );

    }



    return createReflection(

      title: 'Reflection: $giftTitle',

      body: trimmedBody,

      source: ReflectionSource.giftActivity,

      linkedGiftId: giftId,

      linkedSourceTitle: giftTitle,

    );

  }



  /// Appends a new dated entry to an existing thread.

  Future<ReflectionEntry> appendEntry({

    required String threadId,

    required String body,

  }) async {

    final threads = _threadsCol;

    final entries = _entriesCol(threadId);

    if (threads == null || entries == null) {

      throw Exception('Sign in to save reflections.');

    }



    final trimmedBody = body.trim();

    if (trimmedBody.isEmpty) {

      throw Exception('Reflection text cannot be empty.');

    }



    final threadSnap = await threads.doc(threadId).get();

    if (!threadSnap.exists) {

      throw Exception('Reflection not found.');

    }



    final entryId = _uuid.v4();

    final preview = _previewFor(trimmedBody);

    final currentCount = threadSnap.data()?['entryCount'] as int? ?? 0;

    final batch = _firestore.batch();



    batch.set(entries.doc(entryId), {

      'threadId': threadId,

      'body': trimmedBody,

      'createdAt': FieldValue.serverTimestamp(),

    });



    batch.update(threads.doc(threadId), {

      'entryCount': currentCount + 1,

      'lastEntryPreview': preview,

      'updatedAt': FieldValue.serverTimestamp(),

    });



    await batch.commit();



    return ReflectionEntry(

      id: entryId,

      threadId: threadId,

      body: trimmedBody,

      createdAt: DateTime.now(),

    );

  }



  Future<void> _updateLatestEntry(String threadId, String body) async {

    final threads = _threadsCol;

    final entries = _entriesCol(threadId);

    if (threads == null || entries == null) {

      throw Exception('Sign in to save reflections.');

    }



    final preview = _previewFor(body);

    final snap = await entries.orderBy('createdAt', descending: true).limit(1).get();



    if (snap.docs.isEmpty) {

      await appendEntry(threadId: threadId, body: body);

      return;

    }



    final latest = snap.docs.first;

    await latest.reference.update({'body': body});

    await threads.doc(threadId).update({

      'lastEntryPreview': preview,

      'updatedAt': FieldValue.serverTimestamp(),

    });

  }



  /// Returns true if the whole thread was removed (last entry deleted).

  Future<bool> deleteEntry({

    required String threadId,

    required String entryId,

  }) async {

    final threads = _threadsCol;

    final entries = _entriesCol(threadId);

    if (threads == null || entries == null) {

      throw Exception('Sign in to manage reflections.');

    }



    await entries.doc(entryId).delete();



    final remaining = await entries.orderBy('createdAt', descending: true).get();

    if (remaining.docs.isEmpty) {

      await threads.doc(threadId).delete();

      return true;

    }



    final latest = ReflectionEntry.fromMap(

      remaining.docs.first.id,

      remaining.docs.first.data(),

    );

    await threads.doc(threadId).update({

      'entryCount': remaining.docs.length,

      'lastEntryPreview': _previewFor(latest.body),

      'updatedAt': FieldValue.serverTimestamp(),

    });

    return false;

  }



  Future<void> deleteThread(String threadId) async {

    final threads = _threadsCol;

    final entries = _entriesCol(threadId);

    if (threads == null || entries == null) {

      throw Exception('Sign in to manage reflections.');

    }



    final entrySnap = await entries.get();

    final batch = _firestore.batch();

    for (final doc in entrySnap.docs) {

      batch.delete(doc.reference);

    }

    batch.delete(threads.doc(threadId));

    await batch.commit();

  }



  static String _previewFor(String body) {

    final trimmed = body.trim();

    if (trimmed.length <= 120) return trimmed;

    return '${trimmed.substring(0, 120)}…';

  }

}

