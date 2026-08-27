import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/content_guidance/content_detector.dart';
import 'package:wwjd_app/core/content_guidance/private_content_guidance.dart';
import 'package:wwjd_app/core/content_guidance/shared_content_processor.dart';
import 'package:wwjd_app/core/content_guidance/content_guidance_models.dart';

void main() {
  group('ContentDetector', () {
    test('detects explicit sexual content', () {
      expect(
        ContentDetector.containsExplicitSexualContent(
          'Is it okay to have sex with my girlfriend?',
        ),
        isTrue,
      );
    });

    test('detects graphic sexual act language', () {
      expect(
        ContentDetector.requiresSharedPastoralReframe(
          'My boyfriend asked me to suck his penis',
        ),
        isTrue,
      );
    });

    test('detects abuse or victimization disclosures', () {
      expect(
        ContentDetector.indicatesAbuseOrVictimization(
          'My dad touches me inappropriately when I am in bed, what should I do?',
        ),
        isTrue,
      );
    });

    test('does not treat abuse disclosures as chastity reframe candidates', () {
      expect(
        ContentDetector.requiresSharedPastoralReframe(
          'My dad touches me inappropriately when I am in bed, what should I do?',
        ),
        isFalse,
      );
    });

    test('detects third-party identification', () {
      expect(
        ContentDetector.containsThirdPartyIdentification(
          'My girlfriend Sarah is pressuring me.',
        ),
        isTrue,
      );
    });

    test('detects relationship role without a name', () {
      expect(
        ContentDetector.containsThirdPartyIdentification(
          'My boyfriend keeps pressuring me.',
        ),
        isTrue,
      );
    });

    test('does not flag chaste pastoral wording', () {
      expect(
        ContentDetector.containsExplicitSexualContent(
          'How can I grow in chastity and sexual integrity?',
        ),
        isFalse,
      );
    });
  });

  group('SharedContentProcessor', () {
    final processor = SharedContentProcessor();

    test('reframes explicit question for shared publication', () {
      final result = processor.process(
        const SharedContentInput(
          question: 'Can I have sex with my girlfriend tonight?',
        ),
      );

      expect(result.wasModified, isTrue);
      expect(result.revised.question, contains('sexual activity'));
      expect(result.revised.question, isNot(contains('sex with')));
      expect(result.revised.question, isNot(contains('girlfriend')));
      expect(result.requiresAnonymousSharing, isTrue);
      expect(
        ContentDetector.isSchoolAppropriateForShared(result.revised.question!),
        isTrue,
      );
    });

    test('fully reframes graphic sexual requests without partial edits', () {
      const original = 'My boyfriend asked me to suck his penis';
      final result = processor.process(
        const SharedContentInput(question: original),
      );

      expect(result.wasModified, isTrue);
      expect(result.hadExplicitContent, isTrue);
      expect(result.revised.question, isNot(contains('suck')));
      expect(result.revised.question, isNot(contains('penis')));
      expect(result.revised.question, isNot(contains('boyfriend')));
      expect(result.revised.question, contains('chastity'));
      expect(result.requiresAnonymousSharing, isTrue);
      expect(
        ContentDetector.isSchoolAppropriateForShared(result.revised.question!),
        isTrue,
      );
    });

    test('preserves abuse disclosure meaning and requires anonymous sharing', () {
      const original =
          'My dad touches me inappropriately when I am in bed, what should I do?';
      final result = processor.process(
        const SharedContentInput(question: original),
      );

      expect(result.hadAbuseOrVictimization, isTrue);
      expect(result.requiresAnonymousSharing, isTrue);
      expect(result.revised.question, contains('inappropriately'));
      expect(result.revised.question, contains('parent'));
      expect(result.revised.question, isNot(contains('chastity')));
      expect(result.revised.question, isNot(contains('relationship')));
      expect(result.revised.question, contains('what should I do'));
    });

    test('reframes named third party with explicit act language', () {
      final result = processor.process(
        const SharedContentInput(
          question: 'My boyfriend Jake asked me to suck his penis',
        ),
      );

      expect(result.wasModified, isTrue);
      expect(result.revised.question, isNot(contains('Jake')));
      expect(result.revised.question, isNot(contains('suck')));
      expect(result.revised.question, isNot(contains('penis')));
      expect(
        ContentDetector.isSchoolAppropriateForShared(result.revised.question!),
        isTrue,
      );
    });

    test('generalizes named third parties without explicit content', () {
      final result = processor.process(
        const SharedContentInput(
          question: 'My classmate Emma keeps tempting me.',
        ),
      );

      expect(result.wasModified, isTrue);
      expect(result.revised.question, contains('someone from school'));
      expect(result.revised.question, isNot(contains('Emma')));
      expect(result.hadExplicitContent, isFalse);
      expect(result.requiresAnonymousSharing, isTrue);
    });

    test('leaves chaste relationship questions appropriately generalized only', () {
      final result = processor.process(
        const SharedContentInput(
          question: 'How can I support my girlfriend in growing closer to God?',
        ),
      );

      expect(result.wasModified, isTrue);
      expect(result.revised.question, contains('someone I\'m in a relationship with'));
      expect(result.revised.question, isNot(contains('girlfriend')));
      expect(result.hadExplicitContent, isFalse);
      expect(result.requiresAnonymousSharing, isTrue);
    });

    test('does not require anonymous sharing without third-party references', () {
      final result = processor.process(
        const SharedContentInput(
          question: 'How can I grow in patience when people frustrate me?',
        ),
      );

      expect(result.wasModified, isFalse);
      expect(result.requiresAnonymousSharing, isFalse);
    });
  });

  group('PrivateContentGuidance', () {
    test('offers suggestion without blocking crude language', () {
      final guidance = PrivateContentGuidance();
      final suggestion = guidance.suggest(
        'I want to know if having sex is okay.',
      );

      expect(suggestion.hasSuggestion, isTrue);
      expect(suggestion.suggestedRephrase, contains('chastity'));
      expect(suggestion.original, contains('sex'));
    });

    test('returns no suggestion for ordinary questions', () {
      final guidance = PrivateContentGuidance();
      final suggestion = guidance.suggest(
        'How can I forgive someone who hurt me?',
      );

      expect(suggestion.hasSuggestion, isFalse);
    });
  });
}
