import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/analytics/usage_analytics_service.dart';
import '../core/analytics/usage_section.dart';
import '../core/providers/app_providers.dart';
import '../core/saints/saint_calendar.dart';
import '../core/saints/saint_url_debug.dart';
import '../models/saint_video.dart';
import '../core/repositories/saints_repository.dart';
import '../widgets/main_shell_nav.dart';
import '../widgets/saint_player.dart';
import '../widgets/saint_poster_image.dart';

/// “Today in the Church” — feast-day saint videos from Firestore / Storage.
class SaintsCalendarPage extends ConsumerStatefulWidget {
  const SaintsCalendarPage({super.key});

  @override
  ConsumerState<SaintsCalendarPage> createState() => _SaintsCalendarPageState();
}

class _SaintsCalendarPageState extends ConsumerState<SaintsCalendarPage> {
  @override
  void initState() {
    super.initState();
    SaintCalendar.ensureInitialized();
    UsageAnalyticsService.instance.trackSectionView(UsageSection.saints);
  }

  @override
  Widget build(BuildContext context) {
    final saintsAsync = ref.watch(publishedSaintsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saints'),
        centerTitle: true,
      ),
      bottomNavigationBar: const MainShellNav(selectedIndex: 1, alwaysShow: true),
      body: saintsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Saints could not be loaded.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (saints) => _CalendarBody(
          saints: saints,
          repository: ref.read(saintsRepositoryProvider),
        ),
      ),
    );
  }
}

class _CalendarBody extends StatefulWidget {
  const _CalendarBody({
    required this.saints,
    required this.repository,
  });

  final List<SaintEntry> saints;
  final SaintsRepository repository;

  @override
  State<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends State<_CalendarBody> {
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      widget.repository.listPublishedRoutingDebug();
    }
  }

  void _openSaint(BuildContext context, SaintEntry saint) {
    final path = SaintEntry.watchPath(saint.slug);
    debugPrint(
      'Saint tap: name=${saint.name} documentId=${saint.documentId} '
      'slugField=${saint.firestoreSlug} route=$path',
    );
    debugPrint(SaintUrlDebug.describe('poster', saint.posterPortraitUrl));
    debugPrint(SaintUrlDebug.describe('video', saint.videoPortraitUrl));
    GoRouter.of(context).go(path);
  }

  List<SaintEntry> get saints => widget.saints;

  @override
  Widget build(BuildContext context) {
    final feastFilms = SaintCalendar.publishedFeastFilms(saints);
    final legacy = saints.where((s) => !s.isFeastFilm).toList();
    final todaySaint = SaintCalendar.saintForToday(saints);
    final upcoming = SaintCalendar.nextUpcomingSaint(saints);

    if (feastFilms.isEmpty && legacy.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No saint videos are published yet. Feast-day films will appear here '
            'after they are uploaded to Firebase Storage and seeded in Firestore.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Today in the Church',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Feast days follow the civil calendar in America/New_York. '
          'Videos stream from the cloud — nothing is bundled in the app.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.45),
        ),
        const SizedBox(height: 20),
        if (todaySaint != null) ...[
          Text(
            'Today’s feast',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          _FeastHeroCard(
            saint: todaySaint,
            onOpen: () => _openSaint(context, todaySaint),
          ),
        ] else if (upcoming != null) ...[
          Text(
            'Next feast',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
              title: Text(upcoming.name),
              subtitle: Text(
                'Feast in ${SaintCalendar.daysUntilFeast(upcoming)} day'
                '${SaintCalendar.daysUntilFeast(upcoming) == 1 ? '' : 's'} · '
                '${SaintCalendar.feastLabel(upcoming)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSaint(context, upcoming),
              ),
            ),
          ),
        ],
        if (feastFilms.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Saints',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          for (final saint in feastFilms)
            if (todaySaint?.slug != saint.slug)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    leading: _SaintListLeading(saint: saint),
                    title: Text(saint.name),
                    subtitle: Text(SaintCalendar.feastLabel(saint)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openSaint(context, saint),
                  ),
                ),
              ),
        ],
        if (legacy.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Saint series',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Eight-part clip series (legacy format).',
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          for (final saint in legacy)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  title: Text(saint.name),
                  subtitle: Text(saint.feastDayLabel),
                  trailing: const Icon(Icons.play_circle_outline),
                  onTap: () => _openSaint(context, saint),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _SaintListLeading extends StatelessWidget {
  const _SaintListLeading({required this.saint});

  final SaintEntry saint;

  @override
  Widget build(BuildContext context) {
    final poster = saint.posterPortraitUrl?.trim();
    if (poster != null && poster.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 48,
          child: SaintPosterImage(
            url: poster,
            fit: BoxFit.cover,
            saintLabel: saint.name,
          ),
        ),
      );
    }
    return const Icon(Icons.auto_awesome_outlined);
  }
}

class _FeastHeroCard extends StatelessWidget {
  const _FeastHeroCard({
    required this.saint,
    required this.onOpen,
  });

  final SaintEntry saint;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final quote = saint.quote.trim().isNotEmpty
        ? saint.quote.trim()
        : saint.prayLine.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    saint.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    SaintCalendar.feastLabel(saint),
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SaintPlayer(
              saint: saint,
              hero: true,
              startMuted: true,
              autoPlay: true,
            ),
            if (quote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '“$quote”',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                  fontSize: 16,
                ),
              ),
            ],
            if (saint.prayLine.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                saint.prayLine.trim(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_full),
                label: const Text('Open full screen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
