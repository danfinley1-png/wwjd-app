import 'content_guidance_models.dart';

/// Heuristic detection for shared-content guidance (no raw content retention).
class ContentDetector {
  ContentDetector._();

  static final RegExp _emailPattern = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
  );

  static final RegExp _phonePattern = RegExp(
    r'\b(?:\+?\d{1,3}[\s.-]?)?(?:\(\d{3}\)|\d{3})[\s.-]?\d{3}[\s.-]?\d{4}\b',
  );

  static final RegExp _socialHandlePattern = RegExp(r'@[A-Za-z0-9_]{2,}');

  static final RegExp relationshipWithNamePattern = RegExp(
    r'\bmy\s+(girlfriend|boyfriend|wife|husband|fianc[ée]e|partner|ex|crush|classmate|coworker|co-worker|boss|teacher|pastor|priest|friend|roommate|neighbor|neighbour)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)',
    caseSensitive: false,
  );

  static final RegExp relationshipRolePattern = RegExp(
    r'\bmy\s+(girlfriend|boyfriend|wife|husband|fianc[ée]e|partner|ex|crush|classmate|coworker|co-worker|boss|teacher|pastor|priest|friend|roommate|neighbor|neighbour)\b',
    caseSensitive: false,
  );

  static final RegExp familyWithNamePattern = RegExp(
    r'\bmy\s+(dad|father|mom|mother|parent|stepdad|stepfather|stepmom|stepmother|uncle|aunt|grandfather|grandmother|grandpa|grandma|brother|sister|cousin)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)',
    caseSensitive: false,
  );

  static final RegExp familyRolePattern = RegExp(
    r'\bmy\s+(dad|father|mom|mother|stepdad|stepfather|stepmom|stepmother|uncle|aunt|grandfather|grandmother|grandpa|grandma)\b',
    caseSensitive: false,
  );

  static final RegExp namedPersonPattern = RegExp(
    r'\b(?:named|called)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)',
    caseSensitive: false,
  );

  /// Graphic or crude consensual sexual content — warrants full pastoral reframe.
  static final List<RegExp> _graphicConsensualPatterns = [
    RegExp(r'\b(porn|pornography|xxx|nude|nudes|naked)\b', caseSensitive: false),
    RegExp(r'\b(blowjob|handjob|oral sex|anal sex|masturbat\w*)\b', caseSensitive: false),
    RegExp(r'\b(fuck(?:ing|ed|s)?|screw(?:ing|ed)?)\b', caseSensitive: false),
    RegExp(r'\b(horny|orgasm|climax|ejacul\w*)\b', caseSensitive: false),
    RegExp(
      r'\b(have|having|had)\s+sex\b|\bsex\s+with\b|\bsleep(?:ing|s)?\s+with\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(sexual\s+act|sexual\s+activity|sex\s+act|intercourse|fornication|adultery)\b',
      caseSensitive: false,
    ),
    RegExp(r'\b(hentai|onlyfans|hookup|one-night stand)\b', caseSensitive: false),
    RegExp(
      r'\b(suck(?:ed|ing|s)?|blow(?:ing|s)?|lick(?:ed|ing|s)?)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(penis|dick|cock|vagina|pussy|clit(?:oris)?|testicle|scrotum|boob(?:s)?|breasts?)\b',
      caseSensitive: false,
    ),
    RegExp(r'\b(cum(?:ming|med|s)?|jizz|semen|precum)\b', caseSensitive: false),
    RegExp(
      r'\bfinger(?:ed|ing)?\s+(?:me|her|him|them)\b',
      caseSensitive: false,
    ),
    RegExp(r'\b(strip(?:ped|ping|tease)?)\b', caseSensitive: false),
    RegExp(
      r'\b(asked|wanted|told|pressured|made)\s+me\s+to\s+(?:have|do|perform|suck|blow|lick)\b',
      caseSensitive: false,
    ),
    RegExp(r'\bmake\s+out\b', caseSensitive: false),
    RegExp(r'\b69\b'),
  ];

  /// Possible abuse, assault, or victimization — preserve meaning; do not reframe as chastity.
  static final List<RegExp> _abuseIndicatorPatterns = [
    RegExp(r'\b(rape|raped|raping|sexual\s+assault)\b', caseSensitive: false),
    RegExp(r'\b(molest(?:ed|ing|s)?|groom(?:ed|ing|s)?)\b', caseSensitive: false),
    RegExp(
      r'\b(sexual(?:ly)?\s+abus(?:e|ed|ing|er)|abusive\s+sexual)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(inappropriat(?:e|ely)\s+(?:touch(?:ed|ing|es)?|behavior|contact|acts?))\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\btouch(?:ed|ing|es)?\s+me\s+inappropriat(?:e|ely)\b',
      caseSensitive: false,
    ),
    RegExp(r'\b(victim(?:ized|ization)?)\b', caseSensitive: false),
    RegExp(
      r'\b(forced\s+me\s+(?:to|into))\b',
      caseSensitive: false,
    ),
  ];

  static final RegExp _familyAuthorityFigurePattern = RegExp(
    r'\b(?:my\s+)?(?:dad|father|mom|mother|parent|step(?:dad|father|mom|mother)|'
    r'uncle|aunt|grand(?:father|mother|pa|ma)|brother|sister|cousin|'
    r'teacher|coach|priest|pastor|boss|youth\s+minister)\b',
    caseSensitive: false,
  );

  static final RegExp _abuseBehaviorPattern = RegExp(
    r'\b(?:inappropriat(?:e|ely)|abuse|abused|abusing|molest|assault|rape|raped|'
    r'touch(?:ed|ing|es)?|groom(?:ed|ing)?|exploit(?:ed|ing)?)\b',
    caseSensitive: false,
  );

  /// Patterns that must never appear in published shared content (graphic/crude only).
  static final List<RegExp> _sharedBannedPatterns = [
    RegExp(r'\b(porn|pornography|xxx|nude|nudes|naked)\b', caseSensitive: false),
    RegExp(r'\b(blowjob|handjob|oral sex|anal sex|masturbat\w*)\b', caseSensitive: false),
    RegExp(r'\b(fuck(?:ing|ed|s)?|screw(?:ing|ed)?)\b', caseSensitive: false),
    RegExp(r'\b(horny|orgasm|climax|ejacul\w*)\b', caseSensitive: false),
    RegExp(
      r'\b(have|having|had)\s+sex\b|\bsex\s+with\b|\bsleep(?:ing|s)?\s+with\b',
      caseSensitive: false,
    ),
    RegExp(r'\b(hentai|onlyfans|hookup|one-night stand)\b', caseSensitive: false),
    RegExp(
      r'\b(suck(?:ed|ing|s)?|blow(?:ing|s)?|lick(?:ed|ing|s)?)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(penis|dick|cock|vagina|pussy|clit(?:oris)?|testicle|scrotum|boob(?:s)?|breasts?)\b',
      caseSensitive: false,
    ),
    RegExp(r'\b(cum(?:ming|med|s)?|jizz|semen|precum)\b', caseSensitive: false),
    RegExp(
      r'\bfinger(?:ed|ing)?\s+(?:me|her|him|them)\b',
      caseSensitive: false,
    ),
    RegExp(r'\b(strip(?:ped|ping|tease)?)\b', caseSensitive: false),
    RegExp(r'\bmake\s+out\b', caseSensitive: false),
    RegExp(r'\b69\b'),
  ];

  /// Crude language that warrants a gentle private rephrase suggestion.
  static final List<RegExp> _crudePrivatePatterns = [
    ..._graphicConsensualPatterns,
    ..._abuseIndicatorPatterns,
    RegExp(r'\b(grope|molest)\b', caseSensitive: false),
    RegExp(r'\b(damn|hell|crap|stupid\s+idiot)\b', caseSensitive: false),
  ];

  static bool indicatesAbuseOrVictimization(String text) {
    if (text.trim().isEmpty) return false;
    if (_abuseIndicatorPatterns.any((pattern) => pattern.hasMatch(text))) {
      return true;
    }

    if (!_familyAuthorityFigurePattern.hasMatch(text)) return false;
    return _abuseBehaviorPattern.hasMatch(text);
  }

  static bool containsExplicitSexualContent(String text) {
    if (text.trim().isEmpty) return false;
    return _graphicConsensualPatterns.any((pattern) => pattern.hasMatch(text)) ||
        _abuseIndicatorPatterns.any((pattern) => pattern.hasMatch(text));
  }

  /// True when shared content needs a full chastity/purity reframe (consensual explicit only).
  static bool requiresSharedPastoralReframe(String text) {
    if (indicatesAbuseOrVictimization(text)) return false;
    return _graphicConsensualPatterns.any((pattern) => pattern.hasMatch(text));
  }

  static bool containsCrudeOrExplicitLanguage(String text) {
    if (text.trim().isEmpty) return false;
    return _crudePrivatePatterns.any((pattern) => pattern.hasMatch(text));
  }

  static bool containsThirdPartyIdentification(String text) {
    if (text.trim().isEmpty) return false;
    if (_emailPattern.hasMatch(text)) return true;
    if (_phonePattern.hasMatch(text)) return true;
    if (_socialHandlePattern.hasMatch(text)) return true;
    if (relationshipWithNamePattern.hasMatch(text)) return true;
    if (relationshipRolePattern.hasMatch(text)) return true;
    if (familyWithNamePattern.hasMatch(text)) return true;
    if (namedPersonPattern.hasMatch(text)) return true;
    return false;
  }

  /// Final safety check before shared publication (skipped for abuse disclosures).
  static bool isSchoolAppropriateForShared(String text) {
    if (text.trim().isEmpty) return true;
    if (indicatesAbuseOrVictimization(text)) return true;
    return !_sharedBannedPatterns.any((pattern) => pattern.hasMatch(text));
  }

  static List<ContentIssueKind> analyzeSharedField(String text) {
    final issues = <ContentIssueKind>[];
    if (indicatesAbuseOrVictimization(text)) {
      issues.add(ContentIssueKind.abuseOrVictimization);
    } else if (requiresSharedPastoralReframe(text)) {
      issues.add(ContentIssueKind.sexuallyExplicit);
    }
    if (containsThirdPartyIdentification(text)) {
      issues.add(ContentIssueKind.thirdPartyIdentification);
    }
    return issues;
  }
}
