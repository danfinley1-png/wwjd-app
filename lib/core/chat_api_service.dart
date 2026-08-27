import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'config.dart';
import 'wwjd_system_prompt.dart';

class ChatApiException implements Exception {
  ChatApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Calls xAI (direct locally, `/api/chat` proxy in production web).
class ChatApiService {
  static const Duration _timeout = Duration(seconds: 90);

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

    if (AppConfig.useClientSideXaiKey && !AppConfig.hasXaiApiKey) {
      throw ChatApiException(
        'xAI API key is not configured for local development.\n\n'
        'Set XAI_API_KEY in .env and run with `--dart-define-from-file=.env`.',
      );
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (AppConfig.useClientSideXaiKey && AppConfig.hasXaiApiKey)
        'Authorization': 'Bearer ${AppConfig.xaiApiKey}',
    };

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(AppConfig.chatCompletionsUrl),
            headers: headers,
            body: jsonEncode({
              'model': 'grok-3',
              'messages': [
                {
                  'role': 'system',
                  'content': WwjdSystemPrompt.forChat(
                    timeContext:
                        '$greeting on ${DateFormat('EEEE').format(timestamp)}.',
                  ),
                },
                {'role': 'user', 'content': userMessage},
              ],
              'temperature': 0.78,
              'max_tokens': 1200,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw ChatApiException(
        'The request timed out after ${_timeout.inSeconds} seconds.\n\n'
        'Please try again.',
      );
    }

    final body = response.body.trim();
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();

    if (body.startsWith('<!DOCTYPE') ||
        body.startsWith('<html') ||
        contentType.contains('text/html')) {
      throw ChatApiException(
        'The AI service is not available on this site yet.\n\n'
        'Deploy Firebase Functions with the XAI_API_KEY secret, then redeploy hosting:\n'
        'firebase functions:secrets:set XAI_API_KEY\n'
        'firebase deploy --only functions,hosting',
      );
    }

    if (response.statusCode != 200) {
      String detail = body;
      try {
        final err = jsonDecode(body);
        if (err is Map && err['error'] != null) {
          detail = err['error'].toString();
        }
      } catch (_) {}
      throw ChatApiException('API error ${response.statusCode}: $detail');
    }

    try {
      final data = jsonDecode(body);
      if (data is! Map || data['choices'] is! List || (data['choices'] as List).isEmpty) {
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

    if (AppConfig.useClientSideXaiKey && !AppConfig.hasXaiApiKey) {
      throw ChatApiException(
        'xAI API key is not configured for local development.\n\n'
        'Set XAI_API_KEY in .env and run with `--dart-define-from-file=.env`.',
      );
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (AppConfig.useClientSideXaiKey && AppConfig.hasXaiApiKey)
        'Authorization': 'Bearer ${AppConfig.xaiApiKey}',
    };

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(AppConfig.chatCompletionsUrl),
            headers: headers,
            body: jsonEncode({
              'model': 'grok-3',
              'messages': [
                {
                  'role': 'system',
                  'content': WwjdSystemPrompt.forDelveDeeperSystem(
                    timeContext:
                        '$greeting on ${DateFormat('EEEE').format(timestamp)}.',
                  ),
                },
                {'role': 'user', 'content': delveUserMessage},
              ],
              'temperature': 0.72,
              'max_tokens': 1400,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw ChatApiException(
        'The request timed out after ${_timeout.inSeconds} seconds.\n\n'
        'Please try again.',
      );
    }

    final body = response.body.trim();
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();

    if (body.startsWith('<!DOCTYPE') ||
        body.startsWith('<html') ||
        contentType.contains('text/html')) {
      throw ChatApiException(
        'The AI service is not available on this site yet.\n\n'
        'Deploy Firebase Functions with the XAI_API_KEY secret, then redeploy hosting:\n'
        'firebase functions:secrets:set XAI_API_KEY\n'
        'firebase deploy --only functions,hosting',
      );
    }

    if (response.statusCode != 200) {
      String detail = body;
      try {
        final err = jsonDecode(body);
        if (err is Map && err['error'] != null) {
          detail = err['error'].toString();
        }
      } catch (_) {}
      throw ChatApiException('API error ${response.statusCode}: $detail');
    }

    try {
      final data = jsonDecode(body);
      if (data is! Map || data['choices'] is! List || (data['choices'] as List).isEmpty) {
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
}
