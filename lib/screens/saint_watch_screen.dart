import 'package:flutter/material.dart';

import 'saint_detail_page.dart';

/// Deep link target for `/saints/:slug`.
class SaintWatchScreen extends StatelessWidget {
  const SaintWatchScreen({super.key, required this.routeSlug});

  final String routeSlug;

  @override
  Widget build(BuildContext context) {
    return SaintDetailPage(slug: routeSlug);
  }
}
