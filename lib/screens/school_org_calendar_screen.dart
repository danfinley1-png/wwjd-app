import 'package:flutter/material.dart';

import '../spiritual_nourishment/local_worship/models/location_profile_kind.dart';
import '../spiritual_nourishment/local_worship/screens/local_worship_screen.dart';

/// Opens Near Me on the My School tab (shared organization schedule).
class SchoolOrgCalendarScreen extends StatelessWidget {
  const SchoolOrgCalendarScreen({super.key, this.initialOrgId});

  static const path = '/org-calendar';

  final String? initialOrgId;

  @override
  Widget build(BuildContext context) {
    return LocalWorshipScreen(
      initialKindId: LocationProfileKind.school.id,
      initialOrgId: initialOrgId,
    );
  }
}
