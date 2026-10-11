import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/saint_video.dart';
import '../saints/saint_calendar.dart';
import '../saints/saint_url_debug.dart';

/// Reads published saints from Firestore and caches poster URLs locally.
class SaintsRepository {
  SaintsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _posterPrefsPrefix = 'saint_poster_url_';

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(SaintEntry.collectionName);

  Stream<List<SaintEntry>> watchPublished() {
    final controller = StreamController<List<SaintEntry>>.broadcast();
    var feastDocs = <SaintEntry>[];
    var legacyDocs = <SaintEntry>[];
    var feastStreamReady = false;
    var legacyStreamReady = false;

    void emitMerged() {
      // Avoid flashing "no saints" when legacy returns before feast snapshots.
      if (!feastStreamReady || !legacyStreamReady) return;

      final byId = <String, SaintEntry>{};
      for (final entry in [...feastDocs, ...legacyDocs]) {
        if (entry.isPublished) {
          byId[entry.id] = entry;
        }
      }
      final merged = byId.values.toList()
        ..sort(SaintCalendar.compareFeastOrder);
      unawaited(_cachePosterUrls(merged));
      if (!controller.isClosed) {
        controller.add(merged);
      }
    }

    final feastSub = _col
        .where('published', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      feastStreamReady = true;
      feastDocs = snap.docs
          .map((doc) => SaintEntry.fromMap(doc.id, doc.data()))
          .toList();
      emitMerged();
    }, onError: (Object e, StackTrace st) {
      debugPrint('SaintsRepository feast stream: $e\n$st');
      feastStreamReady = true;
      feastDocs = const [];
      emitMerged();
    });

    final legacySub = _col
        .where('status', isEqualTo: SaintPublishStatus.published.firestoreValue)
        .snapshots()
        .listen((snap) {
      legacyStreamReady = true;
      legacyDocs = snap.docs
          .map((doc) => SaintEntry.fromMap(doc.id, doc.data()))
          .where((e) => e.publishedFlag != true)
          .toList();
      emitMerged();
    }, onError: (Object e, StackTrace st) {
      debugPrint('SaintsRepository legacy stream: $e\n$st');
      legacyStreamReady = true;
      legacyDocs = const [];
      emitMerged();
    });

    controller.onCancel = () async {
      await feastSub.cancel();
      await legacySub.cancel();
    };

    return controller.stream;
  }

  /// Resolves `/saints/:slug` — document id first, then Firestore `slug` field.
  Stream<SaintEntry?> watchBySlug(String routeParam) {
    final param = routeParam.trim();
    if (param.isEmpty) return Stream.value(null);

    return _col.doc(param).snapshots().asyncMap((snap) async {
      if (snap.exists && snap.data() != null) {
        return _publishedOrNull(snap.id, snap.data()!);
      }
      return _findPublishedBySlugField(param);
    });
  }

  Future<SaintEntry?> getBySlug(String routeParam) async {
    final param = routeParam.trim();
    if (param.isEmpty) return null;

    final snap = await _col.doc(param).get();
    if (snap.exists && snap.data() != null) {
      return _publishedOrNull(snap.id, snap.data()!);
    }
    return _findPublishedBySlugField(param);
  }

  SaintEntry? _publishedOrNull(String docId, Map<String, dynamic> data) {
    final entry = SaintEntry.fromMap(docId, data);
    if (!entry.isPublished) return null;
    return entry;
  }

  Future<SaintEntry?> _findPublishedBySlugField(String slug) async {
    final q = await _col.where('slug', isEqualTo: slug).limit(1).get();
    if (q.docs.isEmpty) return null;
    final doc = q.docs.first;
    return _publishedOrNull(doc.id, doc.data());
  }

  /// Debug: all published saints with routing fields (localhost diagnostics).
  Future<List<Map<String, String>>> listPublishedRoutingDebug() async {
    final feast = await _col.where('published', isEqualTo: true).get();
    final legacy = await _col
        .where('status', isEqualTo: SaintPublishStatus.published.firestoreValue)
        .get();
    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in [...feast.docs, ...legacy.docs]) {
      byId[doc.id] = doc;
    }
    final rows = byId.values.map((doc) {
      final data = doc.data();
      final entry = SaintEntry.fromMap(doc.id, data);
      final posterRaw = data['posterPortraitUrl']?.toString();
      final videoRaw = data['videoPortraitUrl']?.toString();
      final landscapeRaw = data['videoLandscapeUrl']?.toString();
      final posterDesc = SaintUrlDebug.describe('poster', posterRaw);
      final videoDesc = SaintUrlDebug.describe('videoPortrait', videoRaw);
      final landscapeDesc = SaintUrlDebug.describe('videoLandscape', landscapeRaw);
      final inferred = entry.inferredFeastLandscapeStoragePath;
      return {
        'documentId': doc.id,
        'slugField': data['slug']?.toString() ?? '',
        'routeSlug': entry.slug,
        'name': entry.name,
        'posterDesc': posterDesc,
        'videoDesc': videoDesc,
        'landscapeDesc': landscapeDesc,
        'inferredLandscapePath': inferred ?? '(none)',
      };
    }).toList();
    for (final row in rows) {
      // ignore: avoid_print
      print(
        'Saints routing debug: doc=${row['documentId']} '
        '${row['posterDesc']} ${row['videoDesc']} ${row['landscapeDesc']} '
        'inferred=${row['inferredLandscapePath']}',
      );
    }
    return rows;
  }

  Future<String?> cachedPosterUrl(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_posterPrefsPrefix$slug');
  }

  Future<void> _cachePosterUrls(List<SaintEntry> saints) async {
    final prefs = await SharedPreferences.getInstance();
    final today = SaintCalendar.todayInNewYork();
    final relevant = <SaintEntry>[];
    for (final saint in saints) {
      if (!saint.isFeastFilm) continue;
      final days = SaintCalendar.daysUntilFeast(saint);
      if (days <= 7 || SaintCalendar.isFeastToday(saint)) {
        relevant.add(saint);
      }
    }
    for (final saint in relevant) {
      final url = saint.posterPortraitUrl?.trim();
      if (url == null || url.isEmpty) continue;
      await prefs.setString('$_posterPrefsPrefix${saint.slug}', url);
      final dayKey = 'saint_poster_day_${saint.slug}';
      await prefs.setString(dayKey, '${today.year}-${today.month}-${today.day}');
    }
  }
}
