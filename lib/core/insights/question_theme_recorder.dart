import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;

import '../../models/pastoral_theme.dart';
import '../config.dart';
import 'question_theme_classifier.dart';

/// Sends only a theme tag after local classification.
///
/// Written from:
/// - [lib/screens/home_screen.dart] Seeking God's Wisdom send
/// - [lib/core/services/walk_together_service.dart] reflection share
class QuestionThemeRecorder {
  QuestionThemeRecorder({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static QuestionThemeRecorder? _instance;
  static QuestionThemeRecorder get instance =>
      _instance ??= QuestionThemeRecorder();

  Future<void> recordSeekingWisdom(String questionText) {
    return _record(
      questionText: questionText,
      source: QuestionThemeSource.seekingGodsWisdom,
    );
  }

  Future<void> recordWalkTogetherQuestion(String questionText) {
    return _record(
      questionText: questionText,
      source: QuestionThemeSource.walkTogether,
    );
  }

  Future<void> _record({
    required String questionText,
    required QuestionThemeSource source,
  }) async {
    final theme = QuestionThemeClassifier.classify(questionText);
    if (theme == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) return;
      final scope = await _membershipScope(user.uid);

      for (final endpoint in _recordUrls()) {
        try {
          final response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'theme': theme.firestoreValue,
              'source': source.firestoreValue,
              if (scope.orgId != null) 'organizationId': scope.orgId,
              if (scope.groupId != null) 'groupId': scope.groupId,
            }),
          );
          if (response.statusCode >= 200 && response.statusCode < 300) {
            return;
          }
          if (response.statusCode == 404) continue;
          debugPrint(
            'QuestionThemeRecorder: HTTP ${response.statusCode} at $endpoint',
          );
          return;
        } catch (e) {
          debugPrint('QuestionThemeRecorder: $endpoint → $e');
        }
      }
    } catch (e) {
      debugPrint('QuestionThemeRecorder: $e');
    }
  }

  Future<({String? orgId, String? groupId})> _membershipScope(String uid) async {
    try {
      final orgs = await _firestore
          .collection('users')
          .doc(uid)
          .collection('orgMemberships')
          .get();
      final groups = await _firestore
          .collection('users')
          .doc(uid)
          .collection('groupMemberships')
          .get();

      String? orgId;
      if (orgs.docs.length == 1) {
        orgId = orgs.docs.first.id;
      }
      String? groupId;
      if (groups.docs.length == 1) {
        groupId = groups.docs.first.id;
        orgId ??= groups.docs.first.data()['organizationId'] as String?;
      }
      return (orgId: orgId, groupId: groupId);
    } catch (_) {
      return (orgId: null, groupId: null);
    }
  }

  List<String> _recordUrls() {
    final urls = <String>{
      AppConfig.recordQuestionThemeApiUrl,
      AppConfig.recordQuestionThemeFunctionUrl,
      '${AppConfig.productionWebOrigin}/api/recordQuestionTheme',
    };
    if (kIsWeb) {
      urls.add('${Uri.base.origin}/api/recordQuestionTheme');
      urls.add('${Uri.base.origin}/recordQuestionTheme');
    }
    return urls.toList();
  }
}
