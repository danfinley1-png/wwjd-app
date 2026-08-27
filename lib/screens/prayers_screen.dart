import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/analytics/usage_analytics_service.dart';
import '../core/analytics/usage_section.dart';
import '../core/catholic_prayers/catholic_prayer_catalog.dart';
import 'prayer_detail_screen.dart';

/// Searchable library of standard Catholic prayers.
class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    UsageAnalyticsService.instance.trackSectionView(UsageSection.prayers);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPrayer(CatholicPrayer prayer) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PrayerDetailScreen(prayer: prayer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prayers = CatholicPrayerCatalog.search(_query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayers'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by prayer name…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      ),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Authentic Catholic prayers for reading, listening, and sharing.',
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: prayers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_outlined,
                            size: 56,
                            color: AppColors.primaryMaroon.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No prayers match your search',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try a shorter name such as “Hail Mary” or “Angelus”.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: prayers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final prayer = prayers[index];
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppColors.gold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Icon(
                            Icons.menu_book_outlined,
                            color: AppColors.primaryMaroon.withValues(alpha: 0.85),
                          ),
                          title: Text(
                            prayer.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _previewLine(prayer.body),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openPrayer(prayer),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _previewLine(String body) {
    final line = body.split('\n').firstWhere(
          (part) => part.trim().isNotEmpty,
          orElse: () => '',
        );
    return line.trim();
  }
}

/// Route-friendly entry for the prayer library list.
class PrayersListScreen extends StatelessWidget {
  const PrayersListScreen({super.key});

  @override
  Widget build(BuildContext context) => const PrayersScreen();
}
