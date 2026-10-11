import '../../models/pastoral_theme.dart';

/// Local keyword classifier for admin theme reports.
///
/// Runs on the device. Only the resulting theme tag is sent to
/// `recordQuestionTheme` — never the question text.
class QuestionThemeClassifier {
  QuestionThemeClassifier._();

  static const int minQuestionLength = 8;

  static const Map<PastoralThemeCategory, List<String>> _keywords = {
    PastoralThemeCategory.prayer: [
      'pray',
      'prayer',
      'rosary',
      'novena',
      'intercession',
      'morning offering',
      'liturgy of the hours',
      'divine office',
      'contemplation',
      'meditation',
      'spiritual dryness',
      'how do i talk to god',
    ],
    PastoralThemeCategory.sacraments: [
      'sacrament',
      'confession',
      'reconciliation',
      'eucharist',
      'communion',
      'adoration',
      'baptism',
      'confirmation',
      'holy orders',
      'anointing',
      'last rites',
      'matrimony',
      'mass',
    ],
    PastoralThemeCategory.scripture: [
      'scripture',
      'bible',
      'gospel',
      'psalm',
      'psalms',
      'old testament',
      'new testament',
      'verse',
      'lectionary',
      'what does the bible',
    ],
    PastoralThemeCategory.relationshipsChastity: [
      'chastity',
      'lust',
      'porn',
      'pornography',
      'dating',
      'boyfriend',
      'girlfriend',
      'spouse',
      'marriage',
      'divorce',
      'cohabit',
      'purity',
      'same-sex attraction',
      'friendship',
      'peer pressure',
    ],
    PastoralThemeCategory.sufferingGrief: [
      'grief',
      'grieving',
      'death',
      'died',
      'dying',
      'funeral',
      'cancer',
      'illness',
      'suffering',
      'depression',
      'anxiety',
      'miscarriage',
      'suicide',
      'mourning',
      'pain',
      'hurt so much',
    ],
    PastoralThemeCategory.vocation: [
      'vocation',
      'discern',
      'seminary',
      'priesthood',
      'religious life',
      'consecrated',
      'calling',
      'what should i do with my life',
      'become a priest',
      'become a nun',
      'become a sister',
    ],
    PastoralThemeCategory.moralDecision: [
      'is it a sin',
      'mortal sin',
      'venial',
      'should i',
      'conscience',
      'abortion',
      'contraception',
      'ivf',
      'lying',
      'steal',
      'stealing',
      'honesty',
      'moral',
      'right thing',
      'examine my conscience',
    ],
  };

  /// Returns a theme tag for [text], or null when the text is too short.
  static PastoralThemeCategory? classify(String? text) {
    final normalized = (text ?? '').trim().toLowerCase();
    if (normalized.length < minQuestionLength) return null;

    final scores = <PastoralThemeCategory, int>{};
    for (final entry in _keywords.entries) {
      var score = 0;
      for (final keyword in entry.value) {
        if (normalized.contains(keyword)) score += 1;
      }
      if (score > 0) scores[entry.key] = score;
    }

    if (scores.isEmpty) return PastoralThemeCategory.other;

    PastoralThemeCategory best = PastoralThemeCategory.other;
    var bestScore = 0;
    for (final theme in PastoralThemeCategory.values) {
      if (theme == PastoralThemeCategory.other) continue;
      final score = scores[theme] ?? 0;
      if (score > bestScore) {
        bestScore = score;
        best = theme;
      }
    }
    return bestScore == 0 ? PastoralThemeCategory.other : best;
  }
}
