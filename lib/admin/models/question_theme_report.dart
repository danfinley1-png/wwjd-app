import '../../core/insights/question_theme_aggregator.dart';
import '../../models/pastoral_theme.dart';

class QuestionThemeReport {
  const QuestionThemeReport({
    required this.generatedAt,
    required this.periodDays,
    required this.aggregation,
    this.organizationId,
    this.groupId,
    this.source,
    this.isSynthetic = false,
    this.note,
  });

  final DateTime generatedAt;
  final int? periodDays;
  final String? organizationId;
  final String? groupId;
  final QuestionThemeSource? source;
  final bool isSynthetic;
  final String? note;
  final QuestionThemeAggregation aggregation;

  factory QuestionThemeReport.fromJson(Map<String, dynamic> json) {
    return QuestionThemeReport(
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime.now(),
      periodDays: (json['periodDays'] as num?)?.toInt(),
      organizationId: json['organizationId'] as String?,
      groupId: json['groupId'] as String?,
      source: questionThemeSourceFromFirestore(json['source'] as String?),
      isSynthetic: json['isSynthetic'] as bool? ?? false,
      note: json['note'] as String?,
      aggregation: QuestionThemeAggregation(
        threshold: (json['threshold'] as num?)?.toInt() ?? 8,
        insufficientVolume: json['insufficientVolume'] as bool? ?? true,
        rolledUpFromGroup: json['rolledUpFromGroup'] as bool? ?? false,
        rolledUpToAllThemes: json['rolledUpToAllThemes'] as bool? ?? false,
        cells: _cells(json['cells']),
        allThemesDistinctUsers: (json['allThemesDistinctUsers'] as num?)?.toInt(),
        allThemesSuppressed: json['allThemesSuppressed'] as bool? ?? true,
        seekingWisdomDistinctUsers:
            (json['seekingWisdomDistinctUsers'] as num?)?.toInt(),
        seekingWisdomSuppressed:
            json['seekingWisdomSuppressed'] as bool? ?? true,
        walkTogetherDistinctUsers:
            (json['walkTogetherDistinctUsers'] as num?)?.toInt(),
        walkTogetherSuppressed: json['walkTogetherSuppressed'] as bool? ?? true,
        poolDistinctUsers: (json['poolDistinctUsers'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  static List<QuestionThemeCell> _cells(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((row) {
      final map = Map<String, dynamic>.from(row);
      return QuestionThemeCell(
        theme: pastoralThemeFromFirestore(map['theme'] as String?),
        suppressed: map['suppressed'] as bool? ?? true,
        distinctUsers: (map['distinctUsers'] as num?)?.toInt(),
        previousDistinctUsers: (map['previousDistinctUsers'] as num?)?.toInt(),
        previousSuppressed: map['previousSuppressed'] as bool? ?? true,
        seekingWisdomUsers: (map['seekingWisdomUsers'] as num?)?.toInt(),
        seekingWisdomSuppressed:
            map['seekingWisdomSuppressed'] as bool? ?? true,
        walkTogetherUsers: (map['walkTogetherUsers'] as num?)?.toInt(),
        walkTogetherSuppressed: map['walkTogetherSuppressed'] as bool? ?? true,
      );
    }).toList();
  }
}
