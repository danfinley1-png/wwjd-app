/// Pastoral theme categories for anonymized insights aggregation.
enum PastoralThemeCategory {
  anxietyTrustInGod,
  friendshipsPeerPressure,
  prayerSpiritualDryness,
  faithScienceDoubts,
  vocationFutureDecisions,
  familyRelationships,
  socialMediaIdentity,
  forgivenessReconciliation,
  eucharistAdoration,
  moralQuestions,
}

extension PastoralThemeCategoryLabels on PastoralThemeCategory {
  String get label {
    switch (this) {
      case PastoralThemeCategory.anxietyTrustInGod:
        return 'Anxiety & trust in God';
      case PastoralThemeCategory.friendshipsPeerPressure:
        return 'Friendships & peer pressure';
      case PastoralThemeCategory.prayerSpiritualDryness:
        return 'Prayer & spiritual dryness';
      case PastoralThemeCategory.faithScienceDoubts:
        return 'Faith & science / doubts';
      case PastoralThemeCategory.vocationFutureDecisions:
        return 'Vocation & future decisions';
      case PastoralThemeCategory.familyRelationships:
        return 'Family relationships';
      case PastoralThemeCategory.socialMediaIdentity:
        return 'Social media & identity';
      case PastoralThemeCategory.forgivenessReconciliation:
        return 'Forgiveness & reconciliation';
      case PastoralThemeCategory.eucharistAdoration:
        return 'Eucharist & Adoration';
      case PastoralThemeCategory.moralQuestions:
        return 'Moral questions (chastity, honesty, courage)';
    }
  }
}
