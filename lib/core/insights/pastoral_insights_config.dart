/// Configuration for Phase 1 Pastoral Insights (anonymized, k-anonymity).
class PastoralInsightsConfig {
  PastoralInsightsConfig._();

  /// Minimum distinct conversations before themes or pools are shown.
  static const int kAnonymityThreshold = 10;

  /// Phase 1 uses synthetic demo data only — no live conversation ingestion.
  static const bool useDemoDataOnly = true;

  /// When true, insights screen is visible in the sidebar for all users (legacy demo).
  /// Foundation admin layer routes insights through Administration for authorized leaders.
  static const bool insightsMenuEnabled = false;

  static const String privacyNotice =
      'Individual conversations, My History, and My Reflections remain completely '
      'private. Insights show only aggregated, anonymized theme counts. No names, '
      'accounts, or message content are ever displayed here.';

  static const String demoDataNotice =
      'You are viewing synthetic demonstration data for Catholic youth ministry. '
      'This sample helps leaders preview the insights experience before enough '
      'real aggregated volume exists.';

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
