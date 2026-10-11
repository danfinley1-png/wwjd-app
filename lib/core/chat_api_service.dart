import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'config.dart';
import 'wwjd_system_prompt.dart';

class ChatApiException implements Exception {
  ChatApiException(this.message, {this.code});

  final String message;

  /// Server error code, e.g. GUEST_LIMIT, DAILY_LIMIT, RATE_LIMIT.
  final String? code;

  @override
  String toString() => message;
}

/// Ask WWJD — direct xAI only on debug localhost; otherwise authenticated proxy.
class ChatApiService {
  static const Duration _timeout = Duration(seconds: 90);

  static Future<Map<String, String>> _requestHeaders() async {
    if (AppConfig.useClientSideXaiKey) {
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${AppConfig.xaiApiKey}',
      };
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw ChatApiException('Sign in to Ask WWJD.');
    }
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<String> _postCompletion(Map<String, dynamic> body) async {
    final headers = await _requestHeaders();

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(AppConfig.chatCompletionsUrl),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw ChatApiException(
        'The request timed out after ${_timeout.inSeconds} seconds.\n\n'
        'Please try again.',
      );
    }

    final responseBody = response.body.trim();
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();

    if (responseBody.startsWith('<!DOCTYPE') ||
        responseBody.startsWith('<html') ||
        contentType.contains('text/html')) {
      throw ChatApiException(
        'The AI service is not available on this site yet.\n\n'
        'Deploy Firebase Functions with the XAI_API_KEY secret, then redeploy hosting:\n'
        'firebase functions:secrets:set XAI_API_KEY\n'
        'firebase deploy --only functions,hosting',
      );
    }

    if (response.statusCode == 401) {
      throw ChatApiException(
        'Sign in to Ask WWJD. If you are signed in, sign out and back in.',
      );
    }

    if (response.statusCode == 429 || response.statusCode == 503) {
      String detail = responseBody;
      String? code;
      try {
        final err = jsonDecode(responseBody);
        if (err is Map) {
          if (err['error'] != null) detail = err['error'].toString();
          code = err['code']?.toString();
        }
      } catch (_) {}
      throw ChatApiException(detail, code: code);
    }

    if (response.statusCode != 200) {
      String detail = responseBody;
      try {
        final err = jsonDecode(responseBody);
        if (err is Map && err['error'] != null) {
          detail = err['error'].toString();
        }
      } catch (_) {}
      throw ChatApiException('API error ${response.statusCode}: $detail');
    }

    try {
      final data = jsonDecode(responseBody);
      if (data is! Map ||
          data['choices'] is! List ||
          (data['choices'] as List).isEmpty) {
        throw ChatApiException('Unexpected API response format.');
      }
      return data['choices'][0]['message']['content']?.toString() ??
          'No response received.';
    } on FormatException {
      throw ChatApiException(
        'Could not read the AI response. The server may need to be redeployed.',
      );
    }
  }

  static Future<String> fetchResponse({
    required String userMessage,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final greeting = timestamp.hour < 12
        ? 'Good morning'
        : timestamp.hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return _postCompletion({
      'model': 'grok-3',
      'messages': [
        {
          'role': 'system',
          'content': WwjdSystemPrompt.forChat(
            timeContext: '$greeting on ${DateFormat('EEEE').format(timestamp)}.',
          ),
        },
        {'role': 'user', 'content': userMessage},
      ],
      'temperature': 0.78,
      'max_tokens': 1200,
    });
  }

  /// Delve Deeper — dedicated system prompt and prior-response context.
  static Future<String> fetchDelveDeeperResponse({
    required String delveUserMessage,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final greeting = timestamp.hour < 12
        ? 'Good morning'
        : timestamp.hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return _postCompletion({
      'model': 'grok-3',
      'messages': [
        {
          'role': 'system',
          'content': WwjdSystemPrompt.forDelveDeeperSystem(
            timeContext: '$greeting on ${DateFormat('EEEE').format(timestamp)}.',
          ),
        },
        {'role': 'user', 'content': delveUserMessage},
      ],
      'temperature': 0.72,
      'max_tokens': 1400,
    });
  }
}
