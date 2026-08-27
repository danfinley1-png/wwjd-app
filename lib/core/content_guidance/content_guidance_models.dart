/// Where shared-content guidance was applied (for logging only — no raw text).
enum SharedContentChannel {
  walkTogether,
  groupShare,
  shareLink,
  systemShare,
  giftCommunity,
}

/// Kind of content issue detected.
enum ContentIssueKind {
  sexuallyExplicit,
  thirdPartyIdentification,
  abuseOrVictimization,
}

/// Result of shared-content preparation (revised fields + sharing constraints).
class SharedContentGateResult {
  const SharedContentGateResult({
    required this.input,
    this.requiresAnonymousSharing = false,
  });

  final SharedContentInput input;
  final bool requiresAnonymousSharing;
}

/// Which field was evaluated or adjusted.
enum ContentField {
  question,
  response,
  title,
  personalNote,
  description,
}

extension ContentFieldLabels on ContentField {
  String get label {
    switch (this) {
      case ContentField.question:
        return 'Question';
      case ContentField.response:
        return 'Reflection';
      case ContentField.title:
        return 'Title';
      case ContentField.personalNote:
        return 'Personal note';
      case ContentField.description:
        return 'Description';
    }
  }
}

/// Non-sensitive description of an adjustment (safe to log).
class ContentAdjustment {
  const ContentAdjustment({
    required this.field,
    required this.kind,
    required this.summary,
  });

  final ContentField field;
  final ContentIssueKind kind;
  final String summary;
}

/// Input bundle for shared-content processing.
class SharedContentInput {
  const SharedContentInput({
    this.question,
    this.response,
    this.title,
    this.personalNote,
    this.description,
  });

  final String? question;
  final String? response;
  final String? title;
  final String? personalNote;
  final String? description;

  List<MapEntry<ContentField, String>> get nonEmptyFields {
    final entries = <MapEntry<ContentField, String>>[];
    void add(ContentField field, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        entries.add(MapEntry(field, trimmed));
      }
    }

    add(ContentField.question, question);
    add(ContentField.response, response);
    add(ContentField.title, title);
    add(ContentField.personalNote, personalNote);
    add(ContentField.description, description);
    return entries;
  }

  SharedContentInput copyWith({
    String? question,
    String? response,
    String? title,
    String? personalNote,
    String? description,
  }) {
    return SharedContentInput(
      question: question ?? this.question,
      response: response ?? this.response,
      title: title ?? this.title,
      personalNote: personalNote ?? this.personalNote,
      description: description ?? this.description,
    );
  }
}

/// Output after shared-content processing.
class SharedContentResult {
  const SharedContentResult({
    required this.original,
    required this.revised,
    required this.adjustments,
    this.requiresAnonymousSharing = false,
  });

  final SharedContentInput original;
  final SharedContentInput revised;
  final List<ContentAdjustment> adjustments;
  final bool requiresAnonymousSharing;

  bool get wasModified => adjustments.isNotEmpty;

  bool get needsReview => wasModified || requiresAnonymousSharing;

  bool get hadExplicitContent =>
      adjustments.any((a) => a.kind == ContentIssueKind.sexuallyExplicit);

  bool get hadIdentification =>
      adjustments.any((a) => a.kind == ContentIssueKind.thirdPartyIdentification);

  bool get hadAbuseOrVictimization =>
      adjustments.any((a) => a.kind == ContentIssueKind.abuseOrVictimization);
}

/// Optional gentle suggestion for private spiritual conversation.
class PrivateContentSuggestion {
  const PrivateContentSuggestion({
    required this.original,
    this.suggestedRephrase,
    this.pastoralNote = '',
  });

  final String original;
  final String? suggestedRephrase;
  final String pastoralNote;

  bool get hasSuggestion =>
      suggestedRephrase != null && suggestedRephrase!.trim().isNotEmpty;
}
