import 'content_guidance_models.dart';

/// Pastoral copy for content guidance flows.
class ContentGuidanceMessages {
  ContentGuidanceMessages._();

  static const String privateSuggestionIntro =
      'You may want to consider a framing that invites clarity and peace '
      'as you bring this before God. This is only a suggestion — you can '
      'always continue with your own words.';

  static const String sharedReviewTitle = 'Preparing your share';

  static const String sharedReviewIntro =
      'Walk Together and other shared spaces in WWJD-DI are visible to others '
      'in the faith community. We adjust shared content to protect dignity and '
      'privacy while keeping serious matters truthful and pastorally clear.';

  static const String explicitAdjustmentNote =
      'Explicit sexual language was completely removed and replaced with a '
      'dignified, generalized pastoral question about chastity and sexual '
      'integrity — without graphic detail.';

  static const String identificationAdjustmentNote =
      'Details that could identify another person were generalized or removed. '
      'Shares that reference another person must be posted anonymously.';

  static const String abuseAdjustmentNote =
      'This concerns possible abuse or victimization. The shared version keeps '
      'that meaning so others understand the gravity — only unnecessary '
      'identifying details were softened when needed.';

  static const String anonymousRequiredNote =
      'Because another person could be identified, this share must be posted '
      'anonymously.';

  static const String sharedReviewFooter =
      'Your original wording stays private. The shared version below is what '
      'others will see. You may cancel if you prefer not to share.';

  static String adjustmentBullet(ContentIssueKind kind) {
    switch (kind) {
      case ContentIssueKind.sexuallyExplicit:
        return explicitAdjustmentNote;
      case ContentIssueKind.thirdPartyIdentification:
        return identificationAdjustmentNote;
      case ContentIssueKind.abuseOrVictimization:
        return abuseAdjustmentNote;
    }
  }
}
