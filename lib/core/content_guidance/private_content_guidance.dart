import 'content_detector.dart';
import 'content_guidance_messages.dart';
import 'content_guidance_models.dart';

/// Optional gentle rephrasing for private spiritual conversation — never blocks.
class PrivateContentGuidance {
  PrivateContentGuidance();

  PrivateContentSuggestion suggest(String text) {
    final trimmed = text.trim();
    if (!ContentDetector.containsCrudeOrExplicitLanguage(trimmed)) {
      return PrivateContentSuggestion(original: trimmed);
    }

    final suggested = _gentleRephrase(trimmed);
    return PrivateContentSuggestion(
      original: trimmed,
      suggestedRephrase: suggested,
      pastoralNote: ContentGuidanceMessages.privateSuggestionIntro,
    );
  }

  String _gentleRephrase(String text) {
    if (ContentDetector.containsExplicitSexualContent(text)) {
      if (RegExp(
        r'\b(girlfriend|boyfriend|partner|wife|husband|relationship|dating)\b',
        caseSensitive: false,
      ).hasMatch(text)) {
        return 'I am struggling with questions about chastity and sexual integrity '
            'in my relationship. How can I honor the dignity of the person I love '
            'and seek God\'s will?';
      }
      return 'I am wrestling with questions about chastity, purity, and sexual '
          'integrity. How can I live in a way that honors human dignity and seeks '
          'God\'s will?';
    }

    return 'I am bringing a difficult struggle before God and asking for guidance '
        'on how to respond with virtue, peace, and trust in His mercy.';
  }
}
