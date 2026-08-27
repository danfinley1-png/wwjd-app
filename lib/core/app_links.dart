import 'package:flutter/foundation.dart' show kIsWeb;

import 'config.dart';

/// Shared origin for deep links (share reflections, gift activities, etc.).
class AppLinks {
  AppLinks._();

  static const String productionOrigin = 'https://wwjd-di-e36ce.web.app';

  static String baseOrigin() {
    if (AppConfig.webBaseUrl != null && AppConfig.webBaseUrl!.isNotEmpty) {
      return AppConfig.webBaseUrl!.replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return productionOrigin;
  }

  static String absolutePath(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '${baseOrigin()}$normalized';
  }
}
