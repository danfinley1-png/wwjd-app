import 'package:flutter/material.dart';

import 'question_theme_report_screen.dart';

/// Organization-scoped question theme report (Overall / Org Admin only).
class OrgPastoralInsightsScreen extends StatelessWidget {
  const OrgPastoralInsightsScreen({
    super.key,
    required this.orgId,
  });

  final String orgId;

  @override
  Widget build(BuildContext context) {
    return QuestionThemeReportScreen(orgId: orgId);
  }
}
