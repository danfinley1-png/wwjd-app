import 'tts_voice_config.dart';
import 'tts_voice_preference.dart';

/// Picks the best available system voice for read-aloud.
class TtsVoiceSelector {
  TtsVoiceSelector._();

  static Map<String, String>? selectVoice({
    required List<Map<String, String>> voices,
    required TtsVoicePreference preference,
    required TtsVoiceConfig config,
  }) {
    if (voices.isEmpty) return null;

    final english = voices.where((voice) {
      final locale = voice['locale']?.toLowerCase() ?? '';
      return locale.startsWith('en');
    }).toList();

    if (english.isEmpty) return voices.first;

    final exactNames = preference == TtsVoicePreference.malePastoral
        ? config.maleVoiceNames
        : config.femaleVoiceNames;
    for (final target in exactNames) {
      final match = _findByName(english, target);
      if (match != null) return match;
    }

    final hints = preference == TtsVoicePreference.malePastoral
        ? config.maleVoiceHints
        : config.femaleVoiceHints;
    final oppositeHints = preference == TtsVoicePreference.malePastoral
        ? config.femaleVoiceHints
        : config.maleVoiceHints;

    Map<String, String>? best;
    var bestScore = -1;

    for (final voice in english) {
      final name = voice['name']?.toLowerCase() ?? '';
      if (name.isEmpty) continue;

      if (_containsAny(name, oppositeHints)) continue;

      var score = _scoreVoice(name, hints, config.qualityHints);
      if (score > bestScore) {
        bestScore = score;
        best = voice;
      }
    }

    return best ?? english.first;
  }

  static Map<String, String>? _findByName(
    List<Map<String, String>> voices,
    String target,
  ) {
    final needle = target.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final voice in voices) {
      final name = voice['name']?.toLowerCase() ?? '';
      if (name == needle || name.contains(needle)) return voice;
    }
    return null;
  }

  static bool _containsAny(String name, List<String> hints) {
    for (final hint in hints) {
      if (hint.isEmpty) continue;
      if (name.contains(hint)) return true;
    }
    return false;
  }

  static int _scoreVoice(
    String name,
    List<String> genderHints,
    List<String> qualityHints,
  ) {
    var score = 0;
    for (final hint in genderHints) {
      if (hint.isEmpty) continue;
      if (name.contains(hint)) score += hint.length * 10;
    }
    for (final hint in qualityHints) {
      if (hint.isEmpty) continue;
      if (name.contains(hint)) score += 50;
    }
    return score;
  }

  static List<Map<String, String>> parseVoices(dynamic rawVoices) {
    if (rawVoices is! List) return const [];
    final parsed = <Map<String, String>>[];
    for (final entry in rawVoices) {
      if (entry is! Map) continue;
      final name = entry['name']?.toString() ?? '';
      final locale = entry['locale']?.toString() ?? '';
      if (name.isEmpty) continue;
      parsed.add({'name': name, 'locale': locale});
    }
    return parsed;
  }
}
