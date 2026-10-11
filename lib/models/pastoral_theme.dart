/// Pastoral theme categories for anonymized question reporting.
///
/// Stored as [firestoreValue] on `questionThemeEvents` — never with question
/// text, display name, email, or uid.
enum PastoralThemeCategory {
  prayer,
  sacraments,
  scripture,
  relationshipsChastity,
  sufferingGrief,
  vocation,
  moralDecision,
  other,
}

extension PastoralThemeCategoryLabels on PastoralThemeCategory {
  String get label {
    switch (this) {
      case PastoralThemeCategory.prayer:
        return 'Prayer';
      case PastoralThemeCategory.sacraments:
        return 'Sacraments';
      case PastoralThemeCategory.scripture:
        return 'Scripture';
      case PastoralThemeCategory.relationshipsChastity:
        return 'Relationships / Chastity';
      case PastoralThemeCategory.sufferingGrief:
        return 'Suffering / Grief';
      case PastoralThemeCategory.vocation:
        return 'Vocation';
      case PastoralThemeCategory.moralDecision:
        return 'Moral decision';
      case PastoralThemeCategory.other:
        return 'Other';
    }
  }

  String get firestoreValue {
    switch (this) {
      case PastoralThemeCategory.prayer:
        return 'prayer';
      case PastoralThemeCategory.sacraments:
        return 'sacraments';
      case PastoralThemeCategory.scripture:
        return 'scripture';
      case PastoralThemeCategory.relationshipsChastity:
        return 'relationships_chastity';
      case PastoralThemeCategory.sufferingGrief:
        return 'suffering_grief';
      case PastoralThemeCategory.vocation:
        return 'vocation';
      case PastoralThemeCategory.moralDecision:
        return 'moral_decision';
      case PastoralThemeCategory.other:
        return 'other';
    }
  }
}

PastoralThemeCategory pastoralThemeFromFirestore(String? value) {
  switch (value) {
    case 'prayer':
      return PastoralThemeCategory.prayer;
    case 'sacraments':
      return PastoralThemeCategory.sacraments;
    case 'scripture':
      return PastoralThemeCategory.scripture;
    case 'relationships_chastity':
      return PastoralThemeCategory.relationshipsChastity;
    case 'suffering_grief':
      return PastoralThemeCategory.sufferingGrief;
    case 'vocation':
      return PastoralThemeCategory.vocation;
    case 'moral_decision':
      return PastoralThemeCategory.moralDecision;
    default:
      return PastoralThemeCategory.other;
  }
}

/// Where a tagged question originated.
enum QuestionThemeSource {
  seekingGodsWisdom,
  walkTogether,
}

extension QuestionThemeSourceLabels on QuestionThemeSource {
  String get label {
    switch (this) {
      case QuestionThemeSource.seekingGodsWisdom:
        return "Seeking God's Wisdom";
      case QuestionThemeSource.walkTogether:
        return 'Walk Together';
    }
  }

  String get firestoreValue {
    switch (this) {
      case QuestionThemeSource.seekingGodsWisdom:
        return 'seeking_gods_wisdom';
      case QuestionThemeSource.walkTogether:
        return 'walk_together';
    }
  }
}

QuestionThemeSource? questionThemeSourceFromFirestore(String? value) {
  switch (value) {
    case 'seeking_gods_wisdom':
      return QuestionThemeSource.seekingGodsWisdom;
    case 'walk_together':
      return QuestionThemeSource.walkTogether;
    default:
      return null;
  }
}
