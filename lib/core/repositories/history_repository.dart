import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/chat_message.dart';

/// Result of merging guest/anonymous history into a permanent account.
class HistoryMergeResult {
  final int guestMessageCount;
  final int existingMessageCount;
  final int mergedTotalCount;
  final int newlyAddedCount;

  const HistoryMergeResult({
    required this.guestMessageCount,
    required this.existingMessageCount,
    required this.mergedTotalCount,
    required this.newlyAddedCount,
  });

  bool get hadGuestData => guestMessageCount > 0;
  bool get wasMergedIntoExisting => existingMessageCount > 0 && newlyAddedCount > 0;
}

class HistoryRepository {
  HistoryRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const _localCacheKey = 'wwjd_guest_session_history';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? _docForUid(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    return _firestore.collection('users').doc(uid);
  }

  DocumentReference<Map<String, dynamic>>? get _currentUserDoc =>
      _docForUid(_auth.currentUser?.uid);

  /// Load history for the signed-in user.
  Future<List<ChatMessage>> loadHistory() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    return loadHistoryForUid(uid);
  }

  Future<List<ChatMessage>> loadHistoryForUid(String uid) async {
    final doc = _docForUid(uid);
    if (doc == null) return [];

    try {
      final snap = await doc.get();
      if (!snap.exists) return [];
      final data = snap.data();
      final list = data?['sessionHistory'] as List<dynamic>? ?? [];
      return list
          .whereType<Map>()
          .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e)))
          .where((m) => m.isPersistable)
          .toList();
    } catch (e) {
      print('HistoryRepository.loadHistoryForUid error: $e');
      rethrow;
    }
  }

  Future<void> saveHistory(List<ChatMessage> history) async {
    final doc = _currentUserDoc;
    if (doc == null) return;

    final persistable = history.where((m) => m.isPersistable).toList();
    try {
      await doc.set({
        'sessionHistory': persistable.map((m) => m.toMap()).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('HistoryRepository.saveHistory error: $e');
      rethrow;
    }
  }

  Future<void> saveHistoryForUid(String uid, List<ChatMessage> history) async {
    final doc = _docForUid(uid);
    if (doc == null) return;

    final persistable = history.where((m) => m.isPersistable).toList();
    await doc.set({
      'sessionHistory': persistable.map((m) => m.toMap()).toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> loadLocalGuestCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localCacheKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      print('HistoryRepository.loadLocalGuestCache error: $e');
      return [];
    }
  }

  Future<void> saveLocalGuestCache(List<Map<String, dynamic>> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final persistable = history.where((m) => m['isLoading'] != true && (m['text']?.toString().isNotEmpty ?? false)).toList();
      await prefs.setString(_localCacheKey, jsonEncode(persistable));
    } catch (e) {
      print('HistoryRepository.saveLocalGuestCache error: $e');
    }
  }

  Future<void> clearLocalGuestCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localCacheKey);
    } catch (e) {
      print('HistoryRepository.clearLocalGuestCache error: $e');
    }
  }

  /// Deduplicate and sort messages chronologically.
  List<ChatMessage> mergeHistories(
    List<ChatMessage> existing,
    List<ChatMessage> incoming,
  ) {
    final byKey = <String, ChatMessage>{};

    for (final message in [...existing, ...incoming]) {
      if (!message.isPersistable) continue;
      final key = _dedupeKey(message);
      final current = byKey[key];
      if (current == null) {
        byKey[key] = message;
      } else {
        byKey[key] = _pickMostComplete(current, message);
      }
    }

    final merged = byKey.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return merged;
  }

  List<ChatMessage> mergeHistoryMaps(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> incoming,
  ) {
    return mergeHistories(
      existing.map(ChatMessage.fromMap).toList(),
      incoming.map(ChatMessage.fromMap).toList(),
    );
  }

  String _dedupeKey(ChatMessage message) {
    if (message.id.isNotEmpty) return message.id;
    return '${message.contentHash()}_${message.timestamp.toIso8601String()}';
  }

  ChatMessage _pickMostComplete(ChatMessage a, ChatMessage b) {
    if (b.text.length > a.text.length) return b;
    if (a.text.length > b.text.length) return a;
    if (a.id.isNotEmpty && b.id.isEmpty) return a;
    if (b.timestamp.isAfter(a.timestamp)) return b;
    return a;
  }

  /// Normalize legacy messages missing id/timestamp before merge.
  List<ChatMessage> normalizeMessages(List<Map<String, dynamic>> raw) {
    return raw.map((map) {
      final normalized = Map<String, dynamic>.from(map);
      normalized['id'] ??= const Uuid().v4();
      if (normalized['timestamp'] == null) {
        normalized['timestamp'] = DateTime.now().toIso8601String();
      }
      return ChatMessage.fromMap(normalized);
    }).where((m) => m.isPersistable).toList();
  }

  /// Migrate guest/anonymous history into the current signed-in user.
  Future<HistoryMergeResult> migrateGuestHistoryToCurrentUser({
    required List<ChatMessage> inMemoryHistory,
    String? anonymousUid,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const HistoryMergeResult(
        guestMessageCount: 0,
        existingMessageCount: 0,
        mergedTotalCount: 0,
        newlyAddedCount: 0,
      );
    }

    final localMaps = await loadLocalGuestCache();
    final localMessages = normalizeMessages(localMaps);

    var guestMessages = mergeHistories(inMemoryHistory, localMessages);

    if (anonymousUid != null && anonymousUid != user.uid) {
      try {
        final anonFirestore = await loadHistoryForUid(anonymousUid);
        guestMessages = mergeHistories(guestMessages, anonFirestore);
      } catch (e) {
        // After email/Google sign-in the Auth token is the new uid, so
        // users/{anonymousUid} is no longer readable. Guest Firestore history
        // must be captured before the identity switch; never fail sign-in.
        print(
          'HistoryRepository: skipped guest Firestore history for '
          '$anonymousUid after account switch: $e',
        );
      }
    }

    if (guestMessages.isEmpty) {
      await clearLocalGuestCache();
      return HistoryMergeResult(
        guestMessageCount: 0,
        existingMessageCount: (await loadHistory()).length,
        mergedTotalCount: (await loadHistory()).length,
        newlyAddedCount: 0,
      );
    }

    final existing = await loadHistory();
    final merged = mergeHistories(existing, guestMessages);

    await saveHistory(merged);
    await clearLocalGuestCache();

    return HistoryMergeResult(
      guestMessageCount: guestMessages.length,
      existingMessageCount: existing.length,
      mergedTotalCount: merged.length,
      newlyAddedCount: merged.length - existing.length,
    );
  }

  /// Returns true if a new conversation was appended.
  Future<bool> appendConversationIfMissing({
    required String question,
    required String response,
  }) async {
    final trimmedQuestion = question.trim();
    final trimmedResponse = response.trim();
    if (trimmedQuestion.isEmpty || trimmedResponse.isEmpty) return false;

    final history = await loadHistory();
    final exists = history.any((m) => m.isUser && m.text == trimmedQuestion);
    if (exists) return false;

    final now = DateTime.now();
    final updated = [
      ...history,
      ChatMessage(isUser: true, text: trimmedQuestion, timestamp: now),
      ChatMessage(
        isUser: false,
        text: trimmedResponse,
        timestamp: now.add(const Duration(seconds: 1)),
      ),
    ];
    await saveHistory(updated);
    return true;
  }

  Future<void> deleteConversation(String userQuestion) async {
    final history = await loadHistory();
    final cleaned = <ChatMessage>[];
    var skippingConversation = false;

    for (final msg in history) {
      if (skippingConversation) {
        if (msg.isUser) {
          skippingConversation = false;
          cleaned.add(msg);
        }
        continue;
      }
      if (msg.isUser && msg.text == userQuestion) {
        skippingConversation = true;
        continue;
      }
      cleaned.add(msg);
    }

    await saveHistory(cleaned);
  }

  Future<void> clearHistory() async {
    await saveHistory([]);
    await clearLocalGuestCache();
  }
}
