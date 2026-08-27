import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../platform_utils.dart';

/// Device class for aggregate session reporting (no device identifiers stored).
enum UsageDeviceClass {
  desktop('desktop', 'Desktop'),
  mobile('mobile', 'Mobile'),
  tablet('tablet', 'Tablet');

  const UsageDeviceClass(this.id, this.label);

  final String id;
  final String label;

  /// Firestore counter field name, e.g. `sessionsDesktop`.
  String get sessionsField => 'sessions${id[0].toUpperCase()}${id.substring(1)}';

  static UsageDeviceClass detect({BuildContext? context}) {
    if (context != null) {
      final size = MediaQuery.sizeOf(context);
      final shortest = size.shortestSide;
      if (shortest >= 600) return UsageDeviceClass.tablet;
      if (size.width >= 900 && !isMobileWeb) return UsageDeviceClass.desktop;
    }

    if (kIsWeb) {
      return isMobileWeb ? UsageDeviceClass.mobile : UsageDeviceClass.desktop;
    }

    return UsageDeviceClass.mobile;
  }
}
