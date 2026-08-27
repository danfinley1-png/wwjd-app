import 'package:flutter_test/flutter_test.dart';

import 'package:wwjd_app/core/insights/pastoral_insights_config.dart';
import 'package:wwjd_app/core/services/pastoral_insights_service.dart';
import 'package:wwjd_app/models/pastoral_insights_models.dart';
import 'package:wwjd_app/models/pastoral_theme.dart';

void main() {
  group('PastoralInsightsService', () {
    final service = PastoralInsightsService();

    test('demo data produces visible themes at default filters', () {
      final records = service.loadRecords();
      final result = service.aggregate(records: records);

      expect(result.insufficientData, isFalse);
      expect(result.poolSize, greaterThanOrEqualTo(PastoralInsightsConfig.kAnonymityThreshold));
      expect(result.themeCounts, isNotEmpty);
      for (final theme in result.themeCounts) {
        expect(theme.count, greaterThanOrEqualTo(PastoralInsightsConfig.kAnonymityThreshold));
      }
    });

    test('rolls up when ministry filter is too small', () {
      final now = DateTime(2026, 6, 1);
      final records = <AnonymizedConversationRecord>[
        for (var i = 0; i < 5; i++)
          AnonymizedConversationRecord(
            id: 'tiny_$i',
            theme: PastoralThemeCategory.anxietyTrustInGod,
            ministryGroupId: 'tiny_group',
            ageBand: 'High School',
            recordedAt: now.subtract(Duration(days: i)),
            isDemo: true,
          ),
        ...service.loadRecords(now: now),
      ];

      final result = service.aggregate(
        records: records,
        ministryGroupId: 'tiny_group',
        selectedTimeRange: InsightsTimeRange.last30Days,
        now: now,
      );

      expect(result.insufficientData, isFalse);
      expect(result.rolledUpFromSpecificFilter, isTrue);
      expect(result.level, isNot(InsightsAggregationLevel.specificMinistryGroupAndTimeRange));
    });

    test('returns insufficient when pool never reaches threshold', () {
      final now = DateTime(2026, 6, 1);
      final records = List.generate(
        5,
        (i) => AnonymizedConversationRecord(
          id: 'x_$i',
          theme: PastoralThemeCategory.moralQuestions,
          recordedAt: now.subtract(Duration(days: i)),
          isDemo: true,
        ),
      );

      final result = service.aggregate(records: records, now: now);

      expect(result.insufficientData, isTrue);
      expect(result.themeCounts, isEmpty);
    });
  });
}
