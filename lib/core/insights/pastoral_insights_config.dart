/// Configuration for anonymized pastoral / question-theme insights.
class PastoralInsightsConfig {
  PastoralInsightsConfig._();

  /// Minimum distinct users before a cell may show a number.
  static const int kAnonymityThreshold = 8;

  /// Live events are stored on `questionThemeEvents` via `recordQuestionTheme`.
  /// Synthetic preview is opt-in and must stay labeled.
  static const bool useDemoDataOnly = false;

  /// When true, insights screen is visible in the member sidebar.
  /// Must stay false — this report is admin-only.
  static const bool insightsMenuEnabled = false;

  static const String privacyNotice =
      'Individual conversations, My History, and My Reflections remain completely '
      'private. This report shows only aggregated theme counts. No names, '
      'accounts, question text, or message content are stored or displayed here.';

  static const String demoDataNotice =
      'You are viewing a labeled synthetic demonstration dataset. '
      'These counts are not live Seeking God\'s Wisdom or Walk Together questions.';

  static const String suppressionNotice =
      'A count is shown only when at least 8 distinct people asked in that cell. '
      'Smaller group-and-theme cells roll up to the organization or to all themes.';

  static const Map<String, String> demoMinistryGroups = {
    'st_marys_youth': "St. Mary's Youth Group",
    'parish_confirmation': 'Parish Confirmation Class',
    'campus_ministry': 'Catholic High School Campus Ministry',
  };

  static const List<String> demoAgeBands = [
    'High School',
    'Middle School',
    'Young Adult',
  ];
}
