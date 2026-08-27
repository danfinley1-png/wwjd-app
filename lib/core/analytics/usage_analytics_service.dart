import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'usage_device_class.dart';
import 'usage_section.dart';

/// Lightweight, privacy-safe aggregate usage logging.
///
/// Writes only counters to Firestore — never spiritual content or user identity.
class UsageAnalyticsService {
  UsageAnalyticsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static UsageAnalyticsService? _instance;
  static UsageAnalyticsService get instance =>
      _instance ??= UsageAnalyticsService();

  DateTime? _sessionStartedAt;
  bool _sessionStartLogged = false;
  bool _metaInitialized = false;

  CollectionReference<Map<String, dynamic>> get _days =>
      _firestore.collection('platformUsage').doc('daily').collection('days');

  DocumentReference<Map<String, dynamic>> get _metaDoc =>
      _firestore.collection('platformUsage').doc('meta');

  /// Starts an aggregate session (once per app launch).
  Future<void> startSession(UsageDeviceClass deviceClass) async {
    if (_sessionStartLogged) return;

    if (!await _hasAuthenticatedUser()) {
      debugPrint(
        'UsageAnalyticsService.startSession: skipped — no Firebase Auth user yet.',
      );
      return;
    }

    _sessionStartLogged = true;
    _sessionStartedAt = DateTime.now();

    try {
      await _ensureTrackingMeta();
      final isGuest = _auth.currentUser?.isAnonymous ?? true;
      await _incrementDay({
        'sessionCount': 1,
        deviceClass.sessionsField: 1,
        if (isGuest) 'guestSessions': 1 else 'registeredSessions': 1,
      });
    } catch (e, st) {
      _sessionStartLogged = false;
      _sessionStartedAt = null;
      debugPrint('UsageAnalyticsService.startSession: $e\n$st');
    }
  }

  /// Records session duration when the app backgrounds or closes.
  Future<void> endSession() async {
    final started = _sessionStartedAt;
    if (started == null) return;
    _sessionStartedAt = null;

    final seconds = DateTime.now().difference(started).inSeconds;
    if (seconds <= 0 || seconds > 86400) return;

    try {
      await _incrementDay({'sessionDurationSeconds': seconds});
    } catch (e, st) {
      debugPrint('UsageAnalyticsService.endSession: $e\n$st');
    }
  }

  /// Logs a major section view (aggregate counter only).
  Future<void> trackSectionView(UsageSection section) async {
    try {
      await _ensureTrackingMeta();
      await _incrementDay({'sectionViews.${section.id}': 1});
    } catch (e, st) {
      debugPrint('UsageAnalyticsService.trackSectionView: $e\n$st');
    }
  }

  Future<void> _ensureTrackingMeta() async {
    if (_metaInitialized) return;
    _metaInitialized = true;

    final trackingRef = _metaDoc.collection('docs').doc('tracking');
    try {
      await trackingRef.set(
        {
          'trackingStartedAt': FieldValue.serverTimestamp(),
          'version': 1,
          'note':
              'Detailed usage metrics (screen time, section visits, device class, '
              'guest session volume) are recorded from this date forward.',
        },
        SetOptions(merge: true),
      );
    } catch (e, st) {
      debugPrint('UsageAnalyticsService._ensureTrackingMeta: $e\n$st');
    }
  }

  Future<bool> _hasAuthenticatedUser() async {
    if (_auth.currentUser != null) return true;
    try {
      await _auth.authStateChanges().first.timeout(const Duration(seconds: 5));
    } catch (_) {}
    return _auth.currentUser != null;
  }

  Future<void> _incrementDay(Map<String, int> increments) async {
    if (_auth.currentUser == null) return;

    final dayKey = _dayKey(DateTime.now());
    final updates = <String, dynamic>{
      'dateKey': dayKey,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    for (final entry in increments.entries) {
      updates[entry.key] = FieldValue.increment(entry.value);
    }
    await _days.doc(dayKey).set(updates, SetOptions(merge: true));
  }

  static String _dayKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
