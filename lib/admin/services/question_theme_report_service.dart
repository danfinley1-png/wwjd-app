import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/insights/pastoral_insights_config.dart';
import '../../core/insights/pastoral_insights_demo_data.dart';
import '../../core/insights/question_theme_aggregator.dart';
import '../../models/pastoral_theme.dart';
import '../models/question_theme_report.dart';

class QuestionThemeReportService {
  QuestionThemeReportService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<QuestionThemeReport> fetchReport({
    int? periodDays,
    String? organizationId,
    String? groupId,
    QuestionThemeSource? source,
    bool syntheticPreview = false,
  }) async {
    if (syntheticPreview) {
      return _synthetic(
        periodDays: periodDays,
        organizationId: organizationId,
        groupId: groupId,
        source: source,
      );
    }

    final user = _auth.currentUser;
    if (user == null) throw Exception('Sign in required.');
    final token = await user.getIdToken();
    String? lastError;

    for (final endpoint in _urls()) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'periodDays': periodDays,
            if (organizationId != null && organizationId.isNotEmpty)
              'organizationId': organizationId,
            if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
            if (source != null) 'source': source.firestoreValue,
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          return QuestionThemeReport.fromJson(decoded);
        }
        lastError = _format(endpoint, response.statusCode, response.body);
        debugPrint('QuestionThemeReportService: $lastError');
        if (response.statusCode == 404) continue;
        break;
      } catch (e) {
        lastError = '$endpoint → $e';
        debugPrint('QuestionThemeReportService: $lastError');
      }
    }

    throw Exception(
      lastError ??
          'Question theme report requires the getQuestionThemeReport function. '
              'Deploy with: firebase deploy --only functions,hosting',
    );
  }

  QuestionThemeReport _synthetic({
    int? periodDays,
    String? organizationId,
    String? groupId,
    QuestionThemeSource? source,
  }) {
    final now = DateTime.now();
    final aggregation = QuestionThemeAggregator(
      threshold: PastoralInsightsConfig.kAnonymityThreshold,
    ).aggregate(
      events: PastoralInsightsDemoData.themeEvents(now: now),
      now: now,
      periodDays: periodDays,
      organizationId: organizationId ?? 'synthetic_org',
      groupId: groupId,
      source: source,
    );
    return QuestionThemeReport(
      generatedAt: now,
      periodDays: periodDays,
      organizationId: organizationId,
      groupId: groupId,
      source: source,
      isSynthetic: true,
      note: PastoralInsightsConfig.demoDataNotice,
      aggregation: aggregation,
    );
  }

  List<String> _urls() {
    final urls = <String>{
      AppConfig.questionThemeReportApiUrl,
      AppConfig.questionThemeReportFunctionUrl,
      '${AppConfig.productionWebOrigin}/api/getQuestionThemeReport',
    };
    if (kIsWeb) {
      urls.add('${Uri.base.origin}/api/getQuestionThemeReport');
      urls.add('${Uri.base.origin}/getQuestionThemeReport');
    }
    return urls.toList();
  }

  String _format(String endpoint, int status, String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '$endpoint → HTTP $status';
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {}
    return trimmed;
  }
}
