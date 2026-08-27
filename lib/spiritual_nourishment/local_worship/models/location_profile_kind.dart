import 'package:flutter/material.dart';

/// A named location the user worships from (home, school, later work/travel).
///
/// Tabs and storage keys are derived from [active]. Set [usesLocationLookup]
/// to false for a manual chapel template (no GPS or MassTimes search).
class LocationProfileKind {
  const LocationProfileKind({
    required this.id,
    required this.tabLabel,
    required this.addressLabel,
    required this.addressHint,
    required this.icon,
    this.usesLocationLookup = true,
    this.chapelNameLabel = 'Chapel or parish name',
    this.chapelAddressLabel = 'Chapel address',
    this.chapelBadgeLabel = 'My Parish',
    this.templateIntro =
        'Enter the chapel and its worship times. This profile does not look up nearby churches.',
  });

  final String id;
  final String tabLabel;
  final String addressLabel;
  final String addressHint;
  final IconData icon;

  /// When true, this tab geocodes an address and finds nearby parishes.
  /// When false, the user fills a chapel template by hand.
  final bool usesLocationLookup;

  final String chapelNameLabel;
  final String chapelAddressLabel;
  final String chapelBadgeLabel;
  final String templateIntro;

  static const neighborhood = LocationProfileKind(
    id: 'neighborhood',
    tabLabel: 'My Neighborhood',
    addressLabel: 'Neighborhood street address',
    addressHint: 'Street, city, and ZIP',
    icon: Icons.home_outlined,
  );

  static const school = LocationProfileKind(
    id: 'school',
    tabLabel: 'My School',
    addressLabel: 'School name',
    addressHint: 'School or campus name',
    icon: Icons.school_outlined,
    usesLocationLookup: false,
    chapelBadgeLabel: 'School chapel',
    templateIntro:
        'My School shows the schedule your organization administrator publishes, '
        'plus an optional campus chapel template. Nearby parish lookup stays on My Neighborhood.',
  );

  /// Ready for later profiles such as work or travel — not shown until listed.
  static const work = LocationProfileKind(
    id: 'work',
    tabLabel: 'My Workplace',
    addressLabel: 'Work street address',
    addressHint: 'Office or workplace street address',
    icon: Icons.work_outline,
  );

  static const travel = LocationProfileKind(
    id: 'travel',
    tabLabel: 'Travel',
    addressLabel: 'Travel street address',
    addressHint: 'Hotel or destination street address',
    icon: Icons.luggage_outlined,
  );

  static const List<LocationProfileKind> active = [
    neighborhood,
    school,
  ];

  static LocationProfileKind? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final kind in [...active, work, travel]) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}
