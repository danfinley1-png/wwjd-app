import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_links.dart';
import '../core/saints/saint_calendar.dart';
import '../models/saint_video.dart';
import '../core/providers/app_providers.dart';
import '../core/routing/shell_navigation.dart';
import '../widgets/saint_player.dart';
import '../widgets/saints_sequence_player.dart';
import '../widgets/wwjd_brand_title.dart';
import '../widgets/wwjd_purpose_bar.dart';

/// Full-screen feast-day saint or legacy eight-part series.
class SaintDetailPage extends ConsumerWidget {
  const SaintDetailPage({super.key, required this.slug});

  final String slug;

  void _continueToHome(BuildContext context) {
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saintAsync = ref.watch(saintByIdProvider(slug));

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => goToAppHome(context),
          tooltip: 'Home',
        ),
        title: const WwjdBrandTitle(logoSize: 40),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WwjdPurposeBar(),
          Expanded(
            child: saintAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not open this saint.\n$e')),
              data: (SaintEntry? saint) {
                if (saint == null || !saint.isPublished) {
                  return const Center(
                    child: Text('This saint video is not available.'),
                  );
                }
                if (saint.isFeastFilm) {
                  return _FeastDetailBody(
                    saint: saint,
                    onContinue: () => _continueToHome(context),
                  );
                }
                return _LegacySeriesBody(
                  saint: saint,
                  onContinue: () => _continueToHome(context),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeastDetailBody extends StatelessWidget {
  const _FeastDetailBody({
    required this.saint,
    required this.onContinue,
  });

  final SaintEntry saint;
  final VoidCallback onContinue;

  Future<void> _sharePortraitLink() async {
    final pageUrl = AppLinks.absolutePath(SaintEntry.watchPath(saint.slug));
    final portrait = saint.videoPortraitUrl?.trim();
    final lines = <String>[
      if (saint.prayLine.trim().isNotEmpty) saint.prayLine.trim(),
      if (saint.quote.trim().isNotEmpty) '“${saint.quote.trim()}”',
      pageUrl,
    ];
    if (portrait != null && portrait.isNotEmpty) {
      lines.insert(lines.length - 1, portrait);
    }
    await SharePlus.instance.share(
      ShareParams(text: lines.where((l) => l.isNotEmpty).join('\n\n')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          saint.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          SaintCalendar.feastLabel(saint),
          style: TextStyle(color: Colors.grey.shade800),
        ),
        const SizedBox(height: 16),
        SaintPlayer(
          saint: saint,
          startMuted: true,
          autoPlay: false,
          hero: true,
        ),
        const SizedBox(height: 8),
        Text(
          'Portrait video is default on phones. Wider screens use landscape when provided.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
        ),
        if (saint.quote.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '“${saint.quote.trim()}”',
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 17,
              height: 1.45,
            ),
          ),
        ],
        if (saint.patronage.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Patronage',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(saint.patronage.trim(), style: const TextStyle(height: 1.45)),
        ],
        if (saint.prayLine.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            saint.prayLine.trim(),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onContinue,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Continue'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _sharePortraitLink,
          icon: const Icon(Icons.share_outlined),
          label: const Text('Share'),
        ),
      ],
    );
  }
}

class _LegacySeriesBody extends StatelessWidget {
  const _LegacySeriesBody({
    required this.saint,
    required this.onContinue,
  });

  final SaintEntry saint;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          saint.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (saint.feastDayLabel.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Feast day: ${saint.feastDayLabel.trim()}',
            style: TextStyle(color: Colors.grey.shade800),
          ),
        ],
        if (saint.summary.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(saint.summary.trim(), style: const TextStyle(height: 1.5)),
        ],
        const SizedBox(height: 20),
        SaintsSequencePlayer(
          segments: saint.playableSegments,
          autoPlay: false,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onContinue,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
