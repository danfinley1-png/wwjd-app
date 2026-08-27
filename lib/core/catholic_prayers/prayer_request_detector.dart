import 'catholic_prayer_catalog.dart';

/// Result when a user message is a direct request for a known prayer text.
class PrayerRequestMatch {
  const PrayerRequestMatch({required this.prayer});

  final CatholicPrayer prayer;
}

/// Detects clear requests for authentic Catholic prayer texts vs. discernment questions.
class PrayerRequestDetector {
  PrayerRequestDetector._();

  static const _discernmentSignals = [
    'should i',
    'should we',
    'ought i',
    'is it wrong',
    'is it ok',
    'is it okay',
    'can i',
    'may i',
    'help me',
    'struggling',
    'suffering',
    'marriage',
    'spouse',
    'husband',
    'wife',
    'boyfriend',
    'girlfriend',
    'friend',
    'enemy',
    'forgive',
    'anxiety',
    'depressed',
    'depression',
    'job',
    'workplace',
    'school',
    'parent',
    'child',
    'teenager',
    'dilemma',
    'decision',
    'choose',
    'choosing',
    'relationship',
    'dating',
    'divorce',
    'what would jesus do about',
    'how do i handle',
    'how should i',
    'advice on',
    'situation with',
    'dealing with',
    'conflict with',
    'fight with',
    'angry at',
    'discern',
    'moral',
    'ethical',
    'sinful',
    'tempted',
    'temptation to',
    'because i',
    'when my',
    'when i',
    'my son',
    'my daughter',
  ];

  static const _textRequestPatterns = [
    r'\b(give|show|share|teach|tell|recite|say|pray|learn|need|want|write|provide|send)\b',
    r"\b(what is|what's|what are|words of|text of|full text|entire text)\b",
    r'\b(prayer|prayers|text|words)\b',
  ];

  /// Returns a match when the message clearly asks for a known prayer text.
  static PrayerRequestMatch? detect(String rawMessage) {
    final message = rawMessage.trim();
    if (message.isEmpty) return null;

    final normalized = _normalize(message);
    final prayer = _matchPrayer(normalized);
    if (prayer == null) return null;

    if (_looksLikeDiscernment(normalized)) return null;
    if (!_looksLikeDirectTextRequest(normalized, prayer)) return null;

    return PrayerRequestMatch(prayer: prayer);
  }

  static String _normalize(String message) {
    return message
        .toLowerCase()
        .replaceAll(RegExp(r'[“”"]'), '"')
        .replaceAll(RegExp(r'[`´]'), "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static CatholicPrayer? _matchPrayer(String normalized) {
    CatholicPrayer? best;
    var bestLength = 0;

    for (final prayer in CatholicPrayerCatalog.prayers) {
      for (final alias in prayer.aliases) {
        if (normalized.contains(alias) && alias.length > bestLength) {
          best = prayer;
          bestLength = alias.length;
        }
      }
    }
    return best;
  }

  static bool _looksLikeDiscernment(String normalized) {
    var hits = 0;
    for (final signal in _discernmentSignals) {
      if (normalized.contains(signal)) hits++;
    }

    if (normalized.length > 100 && hits >= 1) return true;
    if (hits >= 2) return true;

    if (RegExp(r'\b(when|whether|why|how often)\b.*\b(pray|prayer)\b')
        .hasMatch(normalized)) {
      return true;
    }

    return false;
  }

  static bool _looksLikeDirectTextRequest(String normalized, CatholicPrayer prayer) {
    final aliasPattern = prayer.aliases.map(RegExp.escape).join('|');
    if (RegExp('^(please\\s+)?(the\\s+)?($aliasPattern)(\\s+prayer)?[.!?]*\$')
        .hasMatch(normalized)) {
      return true;
    }

    for (final pattern in _textRequestPatterns) {
      if (RegExp(pattern).hasMatch(normalized)) return true;
    }

    if (normalized.length <= 72) return true;

    return false;
  }
}
