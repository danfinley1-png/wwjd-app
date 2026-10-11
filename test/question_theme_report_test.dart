import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/insights/pastoral_insights_config.dart';
import 'package:wwjd_app/core/insights/question_theme_aggregator.dart';
import 'package:wwjd_app/core/insights/question_theme_classifier.dart';
import 'package:wwjd_app/models/pastoral_theme.dart';

void main() {
  group('QuestionThemeClassifier', () {
    test('maps Catholic question language onto the admin theme set', () {
      expect(
        QuestionThemeClassifier.classify('How should I pray the Rosary daily?'),
        PastoralThemeCategory.prayer,
      );
      expect(
        QuestionThemeClassifier.classify(
          'I am nervous about going to Confession this week.',
        ),
        PastoralThemeCategory.sacraments,
      );
      expect(
        QuestionThemeClassifier.classify(
          'What does this Gospel verse mean for my life?',
        ),
        PastoralThemeCategory.scripture,
      );
      expect(
        QuestionThemeClassifier.classify(
          'How do I practice chastity while dating?',
        ),
        PastoralThemeCategory.relationshipsChastity,
      );
      expect(
        QuestionThemeClassifier.classify(
          'I am grieving the death of my mother.',
        ),
        PastoralThemeCategory.sufferingGrief,
      );
      expect(
        QuestionThemeClassifier.classify(
          'How do I discern a vocation to the priesthood?',
        ),
        PastoralThemeCategory.vocation,
      );
      expect(
        QuestionThemeClassifier.classify('Is it a sin if I keep lying at work?'),
        PastoralThemeCategory.moralDecision,
      );
      expect(
        QuestionThemeClassifier.classify('What is WWJD-DI used for at home?'),
        PastoralThemeCategory.other,
      );
    });

    test('does not classify very short text', () {
      expect(QuestionThemeClassifier.classify('Hi'), isNull);
      expect(QuestionThemeClassifier.classify(''), isNull);
    });
  });

  group('QuestionThemeAggregator suppression', () {
    final aggregator = QuestionThemeAggregator(
      threshold: PastoralInsightsConfig.kAnonymityThreshold,
    );
    final now = DateTime(2026, 9, 2);

    QuestionThemeEvent event({
      required String user,
      required PastoralThemeCategory theme,
      int daysAgo = 1,
      String? groupId,
      String orgId = 'org1',
      QuestionThemeSource source = QuestionThemeSource.seekingGodsWisdom,
    }) {
      return QuestionThemeEvent(
        theme: theme,
        source: source,
        recordedAt: now.subtract(Duration(days: daysAgo)),
        userHash: user,
        organizationId: orgId,
        groupId: groupId,
      );
    }

    test('hides a theme cell with fewer than 8 distinct users', () {
      final events = [
        for (var i = 0; i < 7; i++)
          event(user: 'u$i', theme: PastoralThemeCategory.prayer),
      ];
      final result = aggregator.aggregate(events: events, now: now, periodDays: 30);
      final prayer = result.cells.singleWhere(
        (c) => c.theme == PastoralThemeCategory.prayer,
      );
      expect(prayer.suppressed, isTrue);
      expect(prayer.distinctUsers, isNull);
      expect(result.insufficientVolume, isTrue);
    });

    test('shows a number at 8 distinct users', () {
      final events = [
        for (var i = 0; i < 8; i++)
          event(user: 'u$i', theme: PastoralThemeCategory.prayer),
      ];
      final result = aggregator.aggregate(events: events, now: now, periodDays: 30);
      final prayer = result.cells.singleWhere(
        (c) => c.theme == PastoralThemeCategory.prayer,
      );
      expect(prayer.suppressed, isFalse);
      expect(prayer.distinctUsers, 8);
      expect(result.insufficientVolume, isFalse);
    });

    test('counts distinct users, not raw question volume', () {
      final events = [
        for (var i = 0; i < 20; i++)
          event(user: 'same', theme: PastoralThemeCategory.scripture, daysAgo: i),
      ];
      final result = aggregator.aggregate(events: events, now: now, periodDays: 30);
      final cell = result.cells.singleWhere(
        (c) => c.theme == PastoralThemeCategory.scripture,
      );
      expect(cell.suppressed, isTrue);
      expect(cell.distinctUsers, isNull);
    });

    test('rolls a tiny group up to the organization', () {
      final events = [
        for (var i = 0; i < 3; i++)
          event(
            user: 'g$i',
            theme: PastoralThemeCategory.vocation,
            groupId: 'tiny',
          ),
        for (var i = 0; i < 8; i++)
          event(
            user: 'o$i',
            theme: PastoralThemeCategory.vocation,
            groupId: 'other',
          ),
      ];
      final result = aggregator.aggregate(
        events: events,
        now: now,
        periodDays: 30,
        organizationId: 'org1',
        groupId: 'tiny',
      );
      expect(result.rolledUpFromGroup, isTrue);
      final vocation = result.cells.singleWhere(
        (c) => c.theme == PastoralThemeCategory.vocation,
      );
      expect(vocation.distinctUsers, 11);
    });

    test('rolls up to all-themes when every theme cell is too small', () {
      final events = [
        for (var i = 0; i < 4; i++)
          event(user: 'p$i', theme: PastoralThemeCategory.prayer),
        for (var i = 0; i < 4; i++)
          event(user: 's$i', theme: PastoralThemeCategory.sacraments),
      ];
      final result = aggregator.aggregate(events: events, now: now, periodDays: 30);
      expect(result.rolledUpToAllThemes, isTrue);
      expect(result.allThemesDistinctUsers, 8);
      expect(result.cells, isEmpty);
    });
  });
}
