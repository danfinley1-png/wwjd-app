import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

import '../../core/analytics/usage_section.dart';
import '../../core/config.dart';
import '../models/usage_report.dart';

/// Loads aggregate platform usage for Super Admin review.
class UsageReportService {
  UsageReportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _days =>
      _firestore.collection('platformUsage').doc('daily').collection('days');

  DocumentReference<Map<String, dynamic>> get _trackingMeta =>
      _firestore.collection('platformUsage').doc('meta').collection('docs').doc('tracking');

  Future<DateTime?> fetchTrackingStartedAt() async {
    try {
      final snap = await _trackingMeta.get();
      if (!snap.exists) return null;
      final ts = snap.data()?['trackingStartedAt'];
      if (ts is Timestamp) return ts.toDate();
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  Future<UsageReport> fetchReport(UsageReportPeriod period) async {
    String? backendNote;

    final fromCloud = await _fetchFromCloudFunction(period);
    if (fromCloud.report != null) {
      return fromCloud.report!;
    }
    backendNote = fromCloud.failureNote;

    final trackingStartedAt = await fetchTrackingStartedAt();
    final engagementResult = await _aggregateEngagement(period);
    if (engagementResult.totals != null) {
      return UsageReport(
        period: period,
        generatedAt: DateTime.now(),
        trackingStartedAt: trackingStartedAt,
        totalRegisteredUsers: 0,
        newRegistrationsInPeriod: 0,
        activeUsers7Days: 0,
        activeUsers30Days: 0,
        guestSessionsInPeriod: engagementResult.totals!.guestSessions,
        totalSessionCount: engagementResult.totals!.sessionCount,
        totalSessionDurationSeconds:
            engagementResult.totals!.sessionDurationSeconds,
        sessionsByDevice: engagementResult.totals!.sessionsByDevice,
        sectionViews: engagementResult.totals!.sectionViews,
        userMetricsFromAuth: false,
        note: backendNote ??
            'User registration and active-user counts require the deployed '
            'getUsageReport Cloud Function. Engagement metrics below are from '
            'Firestore daily aggregates.',
      );
    }

    return _emptyReport(
      period: period,
      trackingStartedAt: trackingStartedAt,
      note: backendNote ??
          engagementResult.failureNote ??
          'Usage analytics backend is not available yet. Deploy with:\n'
          'firebase deploy --only firestore:rules,functions,hosting',
    );
  }

  Future<({UsageReport? report, String? failureNote})> _fetchFromCloudFunction(
    UsageReportPeriod period,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      return (
        report: null,
        failureNote: 'Sign in required to load the usage report.',
      );
    }

    final token = await user.getIdToken();
    String? lastError;

    for (final endpoint in _reportEndpointUrls()) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'periodDays': period.days}),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          return (
            report: UsageReport.fromJson(decoded, period),
            failureNote: null,
          );
        }

        lastError = '$endpoint → HTTP ${response.statusCode}: '
            '${response.body.trim().isEmpty ? 'no body' : response.body.trim()}';
        debugPrint('UsageReportService: $lastError');
      } catch (e) {
        lastError = '$endpoint → $e';
        debugPrint('UsageReportService: $lastError');
      }
    }

    return (
      report: null,
      failureNote: lastError == null
          ? 'getUsageReport Cloud Function is not reachable. '
              'Deploy functions and hosting rewrites.'
          : 'getUsageReport unavailable ($lastError). '
              'Deploy with: firebase deploy --only firestore:rules,functions,hosting',
    );
  }

  List<String> _reportEndpointUrls() {
    final urls = <String>{
      AppConfig.usageReportApiUrl,
      AppConfig.usageReportFunctionUrl,
      '${AppConfig.productionWebOrigin}/api/getUsageReport',
      '${AppConfig.productionWebOrigin}/getUsageReport',
    };

    if (kIsWeb) {
      final origin = Uri.base.origin;
      urls.add('$origin/api/getUsageReport');
      urls.add('$origin/getUsageReport');
    }

    return urls.toList();
  }

  Future<({ _EngagementTotals? totals, String? failureNote })> _aggregateEngagement(
    UsageReportPeriod period,
  ) async {
    final now = DateTime.now();
    final start = period.days == null
        ? DateTime(2020)
        : now.subtract(Duration(days: period.days!));
    final startKey = _dayKey(start);
    final endKey = _dayKey(now);

    try {
      final snap = await _days
          .where('dateKey', isGreaterThanOrEqualTo: startKey)
          .where('dateKey', isLessThanOrEqualTo: endKey)
          .get();

      var sessionCount = 0;
      var sessionDurationSeconds = 0;
      var guestSessions = 0;
      final sessionsByDevice = <String, int>{
        'desktop': 0,
        'mobile': 0,
        'tablet': 0,
      };
      final sectionViews = <String, int>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        sessionCount += _asInt(data['sessionCount']);
        sessionDurationSeconds += _asInt(data['sessionDurationSeconds']);
        guestSessions += _asInt(data['guestSessions']);
        sessionsByDevice['desktop'] =
            sessionsByDevice['desktop']! + _asInt(data['sessionsDesktop']);
        sessionsByDevice['mobile'] =
            sessionsByDevice['mobile']! + _asInt(data['sessionsMobile']);
        sessionsByDevice['tablet'] =
            sessionsByDevice['tablet']! + _asInt(data['sessionsTablet']);

        final views = data['sectionViews'];
        if (views is Map) {
          for (final entry in views.entries) {
            final key = entry.key.toString();
            sectionViews[key] =
                (sectionViews[key] ?? 0) + _asInt(entry.value);
          }
        }
      }

      return (
        totals: _EngagementTotals(
          sessionCount: sessionCount,
          sessionDurationSeconds: sessionDurationSeconds,
          guestSessions: guestSessions,
          sessionsByDevice: sessionsByDevice,
          sectionViews: sectionViews,
        ),
        failureNote: null,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return (
          totals: null,
          failureNote:
              'Firestore denied Super Admin read access to platformUsage. '
              'Deploy rules: firebase deploy --only firestore:rules',
        );
      }
      return (totals: null, failureNote: e.message);
    }
  }

  UsageReport _emptyReport({
    required UsageReportPeriod period,
    DateTime? trackingStartedAt,
    required String note,
  }) {
    return UsageReport(
      period: period,
      generatedAt: DateTime.now(),
      trackingStartedAt: trackingStartedAt,
      totalRegisteredUsers: 0,
      newRegistrationsInPeriod: 0,
      activeUsers7Days: 0,
      activeUsers30Days: 0,
      guestSessionsInPeriod: 0,
      totalSessionCount: 0,
      totalSessionDurationSeconds: 0,
      sessionsByDevice: const {'desktop': 0, 'mobile': 0, 'tablet': 0},
      sectionViews: const {},
      userMetricsFromAuth: false,
      note: note,
    );
  }

  static String _dayKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Ordered section rows for the report UI.
  List<UsageSection> get reportSections => [
        UsageSection.seekingWisdom,
        UsageSection.sharingGifts,
        UsageSection.myReflections,
        UsageSection.prayers,
        UsageSection.localWorship,
        UsageSection.orgCalendar,
        UsageSection.walkTogether,
        UsageSection.spiritualNourishment,
        UsageSection.myHistory,
        UsageSection.pastoralInsights,
        UsageSection.admin,
        UsageSection.other,
      ];
}

class _EngagementTotals {
  const _EngagementTotals({
    required this.sessionCount,
    required this.sessionDurationSeconds,
    required this.guestSessions,
    required this.sessionsByDevice,
    required this.sectionViews,
  });

  final int sessionCount;
  final int sessionDurationSeconds;
  final int guestSessions;
  final Map<String, int> sessionsByDevice;
  final Map<String, int> sectionViews;
}
