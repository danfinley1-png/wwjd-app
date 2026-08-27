import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/worship_preferences.dart';

/// Persists Near Me addresses and My Parish selections.
///
/// Guests (signed out or anonymous) save to device storage only.
/// Registered accounts save to `users/{uid}/spiritualNourishment/localWorship`.
class LocalWorshipPreferenceStore {
  LocalWorshipPreferenceStore({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SharedPreferences? prefs,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _prefs = prefs;

  static const localCacheKey = 'wwjd_local_worship_preferences';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  SharedPreferences? _prefs;

  DocumentReference<Map<String, dynamic>>? _remoteDoc(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('spiritualNourishment')
        .doc('localWorship');
  }

  bool get _persistToAccount {
    final user = _auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<WorshipPreferences> load() async {
    if (_persistToAccount) {
      try {
        final remote = await _loadRemote(_auth.currentUser!.uid);
        if (remote != null && !remote.isEmpty) return remote;
      } catch (_) {
        // Fall through to the local cache so the screen still works offline.
      }
    }
    return _loadLocal();
  }

  Future<void> save(WorshipPreferences preferences) async {
    await _saveLocal(preferences);
    if (!_persistToAccount) return;
    try {
      await _saveRemote(_auth.currentUser!.uid, preferences);
    } catch (_) {
      // Local save already succeeded for this session.
    }
  }

  /// Copies guest device preferences onto a newly signed-in account.
  Future<WorshipPreferences> migrateLocalToSignedInAccount() async {
    if (!_persistToAccount) return load();
    final local = await _loadLocal();
    WorshipPreferences? remote;
    try {
      remote = await _loadRemote(_auth.currentUser!.uid);
    } catch (_) {
      remote = null;
    }
    final merged = WorshipPreferences.mergePreferringExisting(remote, local);
    await _saveRemote(_auth.currentUser!.uid, merged);
    await _saveLocal(merged);
    return merged;
  }

  Future<WorshipPreferences> _loadLocal() async {
    try {
      final prefs = await _ensurePrefs();
      final raw = prefs.getString(localCacheKey);
      if (raw == null || raw.isEmpty) return const WorshipPreferences();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const WorshipPreferences();
      return WorshipPreferences.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const WorshipPreferences();
    }
  }

  Future<void> _saveLocal(WorshipPreferences preferences) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(localCacheKey, jsonEncode(preferences.toMap()));
  }

  Future<WorshipPreferences?> _loadRemote(String uid) async {
    final snap = await _remoteDoc(uid)!.get();
    if (!snap.exists || snap.data() == null) return null;
    return WorshipPreferences.fromMap(snap.data());
  }

  Future<void> _saveRemote(String uid, WorshipPreferences preferences) async {
    await _remoteDoc(uid)!.set(
      {
        ...preferences.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
