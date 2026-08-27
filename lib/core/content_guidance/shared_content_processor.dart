import 'content_detector.dart';
import 'content_guidance_models.dart';

/// Reframes and generalizes text before shared publication.
class SharedContentProcessor {
  SharedContentProcessor();

  SharedContentResult process(SharedContentInput input) {
    final adjustments = <ContentAdjustment>[];
    var requiresAnonymousSharing = false;
    var question = input.question?.trim();
    var response = input.response?.trim();
    var title = input.title?.trim();
    var personalNote = input.personalNote?.trim();
    var description = input.description?.trim();

    String? reviseField(ContentField field, String? value) {
      if (value == null || value.isEmpty) return value;

      final isAbuse = ContentDetector.indicatesAbuseOrVictimization(value);
      final needsReframe = ContentDetector.requiresSharedPastoralReframe(value);
      final needsGeneralization =
          ContentDetector.containsThirdPartyIdentification(value);

      if (!isAbuse && !needsReframe && !needsGeneralization) return value;

      var revised = value;

      if (needsGeneralization) {
        requiresAnonymousSharing = true;
      }

      if (isAbuse) {
        requiresAnonymousSharing = true;
        revised = _reviseAbuseDisclosure(value);
        _addAdjustment(
          adjustments,
          field,
          ContentIssueKind.abuseOrVictimization,
          'Preserved the meaning of a possible abuse or victimization situation; '
          'only softened identifying details where needed',
        );
      } else if (needsReframe) {
        revised = _reframeExplicitContent(value);
        _addAdjustment(
          adjustments,
          field,
          ContentIssueKind.sexuallyExplicit,
          'Removed explicit language and reframed as a dignified pastoral question',
        );
        if (needsGeneralization) {
          _addAdjustment(
            adjustments,
            field,
            ContentIssueKind.thirdPartyIdentification,
            'Removed identifying details about another person',
          );
        }
      } else {
        revised = _generalizeThirdParties(value);
        _addAdjustment(
          adjustments,
          field,
          ContentIssueKind.thirdPartyIdentification,
          'Generalized identifying details about another person',
        );
      }

      if (!isAbuse && !ContentDetector.isSchoolAppropriateForShared(revised)) {
        revised = _reframeExplicitContent(value);
        _addAdjustment(
          adjustments,
          field,
          ContentIssueKind.sexuallyExplicit,
          'Removed explicit language and reframed as a dignified pastoral question',
        );
      }

      return revised.trim().isEmpty
          ? (isAbuse ? value.trim() : _defaultPastoralReframe())
          : revised.trim();
    }

    for (final entry in input.nonEmptyFields) {
      final issues = ContentDetector.analyzeSharedField(entry.value);
      if (issues.isEmpty) continue;

      switch (entry.key) {
        case ContentField.question:
          question = reviseField(entry.key, question);
        case ContentField.response:
          response = reviseField(entry.key, response);
        case ContentField.title:
          title = reviseField(entry.key, title);
        case ContentField.personalNote:
          personalNote = reviseField(entry.key, personalNote);
        case ContentField.description:
          description = reviseField(entry.key, description);
      }
    }

    final referencesIdentifiableThirdParty = input.nonEmptyFields.any(
      (entry) => ContentDetector.containsThirdPartyIdentification(entry.value),
    );

    return SharedContentResult(
      original: input,
      revised: SharedContentInput(
        question: question,
        response: response,
        title: title,
        personalNote: personalNote,
        description: description,
      ),
      adjustments: adjustments,
      requiresAnonymousSharing:
          requiresAnonymousSharing || referencesIdentifiableThirdParty,
    );
  }

  void _addAdjustment(
    List<ContentAdjustment> adjustments,
    ContentField field,
    ContentIssueKind kind,
    String summary,
  ) {
    final alreadyLogged = adjustments.any(
      (adjustment) => adjustment.field == field && adjustment.kind == kind,
    );
    if (alreadyLogged) return;

    adjustments.add(
      ContentAdjustment(field: field, kind: kind, summary: summary),
    );
  }

  String _defaultPastoralReframe() {
    return 'A question was raised regarding how to respond to inappropriate '
        'sexual pressure while seeking to live chastity and honor human dignity.';
  }

  String _reframeExplicitContent(String text) {
    final lower = text.toLowerCase();

    final pressureCue = RegExp(
      r'\b(asked|pressur(?:e|ed|ing)|wanted|told|made|forced|coerc|expect(?:ed|ing|s)?|request(?:ed|ing|s)?)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    final relationshipCue = RegExp(
      r'\b(girlfriend|boyfriend|wife|husband|partner|fianc[ée]e|dating|relationship|marriage|spouse)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (pressureCue && relationshipCue) {
      return 'A concern about maintaining chastity when facing sexual pressure in a relationship.';
    }

    if (pressureCue) {
      return 'A question was raised regarding a request to participate in '
          'inappropriate sexual contact outside of marriage.';
    }

    if (relationshipCue) {
      return 'A question about how to respond to pressure for sexual activity outside of marriage.';
    }

    return _defaultPastoralReframe();
  }

  String _reviseAbuseDisclosure(String text) {
    var output = _generalizeFamilyMembers(text);
    output = _removeContactIdentifiers(output);
    output = _stripGraphicTermsOnly(output);
    return output.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  String _generalizeFamilyMembers(String text) {
    var output = text;

    output = output.replaceAllMapped(
      ContentDetector.familyWithNamePattern,
      (match) => _anonymousFamilyPhrase(match.group(1)?.toLowerCase() ?? 'parent'),
    );

    output = output.replaceAllMapped(
      ContentDetector.familyRolePattern,
      (match) => _anonymousFamilyPhrase(match.group(1)?.toLowerCase() ?? 'parent'),
    );

    output = output.replaceAllMapped(
      ContentDetector.namedPersonPattern,
      (_) => 'someone',
    );

    return output;
  }

  String _anonymousFamilyPhrase(String role) {
    switch (role) {
      case 'dad':
      case 'father':
      case 'mom':
      case 'mother':
        return 'my parent';
      case 'stepdad':
      case 'stepfather':
      case 'stepmom':
      case 'stepmother':
        return 'my stepparent';
      case 'uncle':
      case 'aunt':
        return 'a family member';
      case 'grandfather':
      case 'grandmother':
      case 'grandpa':
      case 'grandma':
        return 'a grandparent';
      default:
        return 'a family member';
    }
  }

  String _generalizeThirdParties(String text) {
    var output = text;

    output = output.replaceAllMapped(
      ContentDetector.relationshipWithNamePattern,
      (match) {
        final role = match.group(1)?.toLowerCase() ?? 'person';
        return _anonymousPhraseForRole(role);
      },
    );

    output = output.replaceAllMapped(
      ContentDetector.relationshipRolePattern,
      (match) {
        final role = match.group(1)?.toLowerCase() ?? 'person';
        return _anonymousPhraseForRole(role);
      },
    );

    output = output.replaceAllMapped(
      ContentDetector.namedPersonPattern,
      (_) => 'someone I know',
    );

    output = _removeContactIdentifiers(output);

    return output.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  String _removeContactIdentifiers(String text) {
    var output = text;

    output = output.replaceAll(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
      '[contact removed]',
    );

    output = output.replaceAll(
      RegExp(
        r'\b(?:\+?\d{1,3}[\s.-]?)?(?:\(\d{3}\)|\d{3})[\s.-]?\d{3}[\s.-]?\d{4}\b',
      ),
      '[contact removed]',
    );

    output = output.replaceAll(
      RegExp(r'@[A-Za-z0-9_]{2,}'),
      '[handle removed]',
    );

    return output;
  }

  String _stripGraphicTermsOnly(String text) {
    var output = text;

    const replacements = {
      r'\b(suck(?:ed|ing|s)?|blow(?:ing|s)?|lick(?:ed|ing|s)?)\b': 'inappropriate sexual contact',
      r'\b(penis|dick|cock|vagina|pussy)\b': 'private areas',
      r'\b(blowjob|handjob|oral sex|anal sex)\b': 'inappropriate sexual acts',
      r'\b(fuck(?:ing|ed|s)?|screw(?:ing|ed)?)\b': 'sexual abuse',
    };

    for (final entry in replacements.entries) {
      output = output.replaceAllMapped(
        RegExp(entry.key, caseSensitive: false),
        (_) => entry.value,
      );
    }

    return output;
  }

  String _anonymousPhraseForRole(String role) {
    switch (role) {
      case 'girlfriend':
      case 'boyfriend':
      case 'partner':
      case 'fiancée':
      case 'fiancé':
      case 'fiancee':
      case 'fiance':
        return 'someone I\'m in a relationship with';
      case 'wife':
      case 'husband':
        return 'my spouse';
      case 'ex':
        return 'someone I used to be close to';
      case 'crush':
        return 'someone I have feelings for';
      case 'classmate':
        return 'someone from school';
      case 'coworker':
      case 'co-worker':
        return 'someone I work with';
      case 'boss':
        return 'someone in authority over me';
      case 'teacher':
        return 'a teacher I know';
      case 'pastor':
      case 'priest':
        return 'a priest I know';
      case 'friend':
        return 'a friend';
      case 'roommate':
        return 'someone I live with';
      case 'neighbor':
      case 'neighbour':
        return 'a neighbor';
      default:
        return 'someone I know';
    }
  }
}
