/// Feature flags and copy for the institutional admin layer.
class AdminConfig {
  AdminConfig._();

  /// Master switch — when false, no admin UI or Firestore admin reads are surfaced.
  static const bool adminLayerEnabled = true;

  /// Emails granted Overall / Super Administrator access (platform scope).
  /// Matched case-insensitively against the signed-in Firebase Auth email.
  static const List<String> foundationAdminEmails = [
    'dan.finley@verizon.net',
  ];

  static bool isFoundationAdmin(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return foundationAdminEmails.contains(email.trim().toLowerCase());
  }

  static const String privacyNotice =
      'Administrators can manage organization membership and view anonymized '
      'Pastoral Insights only. Individual Seeking God\'s Wisdom conversations, '
      'My History, My Reflections, and private journal entries are never visible '
      'to organization leaders.';

  static const String insightsScopeNotice =
      'Insights show aggregated theme counts for your organization\'s groups '
      'with k-anonymity protection. No names, accounts, or message content appear.';

  static const List<String> suggestedAgeBands = [
    'High School',
    'Middle School',
    'Young Adult',
    'Adult',
  ];
}
