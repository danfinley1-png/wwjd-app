import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../core/catholic_prayers/prayer_gift_link.dart';
import '../core/gift_share_payload.dart';
import '../core/providers/app_providers.dart';
import '../core/shared_gift_importer.dart';
import '../models/shared_reflection.dart';
import '../widgets/add_shared_gift_button.dart';
import '../widgets/gift_prayer_link_tile.dart';
import '../widgets/linked_markdown_body.dart';
import '../widgets/auth_modal.dart';

class SharedReflectionScreen extends ConsumerStatefulWidget {
  const SharedReflectionScreen({super.key, required this.shareId});

  final String shareId;

  @override
  ConsumerState<SharedReflectionScreen> createState() =>
      _SharedReflectionScreenState();
}

class _SharedReflectionScreenState extends ConsumerState<SharedReflectionScreen> {
  SharedReflection? _reflection;
  bool _loading = true;
  String? _error;
  bool _savedToJourney = false;
  bool _alreadyInJourney = false;
  bool _showGuestWelcome = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    try {
      final coordinator = ref.read(authCoordinatorProvider);
      final auth = ref.read(authServiceProvider);
      final shareService = ref.read(shareServiceProvider);

      await auth.waitForAuthReady();
      final reflection = await shareService.getShare(widget.shareId);
      if (!mounted) return;

      if (reflection == null) {
        setState(() {
          _loading = false;
          _error = 'This shared reflection could not be found or may have expired.';
        });
        return;
      }

      if (reflection.isGiftShare) {
        if (mounted) {
          setState(() {
            _reflection = reflection;
            _loading = false;
          });
        }
        return;
      }

      if (auth.hasRegisteredAccount) {
        await ref.read(sessionHistoryProvider.notifier).loadSessionFromFirebase();
        final history = ref.read(sessionHistoryProvider);
        final saved = await coordinator.saveSharedReflectionToJourney(
          reflection: reflection,
          currentHistory: history,
        );
        await ref.read(sessionHistoryProvider.notifier).loadSessionFromFirebase();
        if (mounted) {
          setState(() {
            _reflection = reflection;
            _loading = false;
            _savedToJourney = saved;
            _alreadyInJourney = !saved;
          });
        }
        return;
      }

      await coordinator.ensureSession(allowGuest: true);
      await ref.read(sessionHistoryProvider.notifier).initialize();

      if (mounted) {
        setState(() {
          _reflection = reflection;
          _loading = false;
          _showGuestWelcome = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load shared reflection: $e';
        });
      }
    }
  }

  void _openAuthToSave() {
    showAuthModal(
      context,
      ref,
      navigateHomeOnSuccess: false,
      onAuthSuccess: () => _saveReflectionAfterAuth(),
    );
  }

  Future<void> _saveReflectionAfterAuth() async {
    if (!mounted || _reflection == null) return;

    final auth = ref.read(authServiceProvider);
    if (!auth.hasRegisteredAccount) return;

    try {
      await ref.read(sessionHistoryProvider.notifier).loadSessionFromFirebase();
      final saved = await ref.read(authCoordinatorProvider).saveSharedReflectionToJourney(
            reflection: _reflection!,
            currentHistory: ref.read(sessionHistoryProvider),
          );
      await ref.read(sessionHistoryProvider.notifier).loadSessionFromFirebase();
      if (mounted) {
        setState(() {
          _savedToJourney = saved;
          _alreadyInJourney = !saved;
          _showGuestWelcome = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved ? 'Saved to your journey' : 'Already in your journey',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_reflection?.isGiftShare == true ? 'Shared Gift' : 'Shared Reflection'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Home',
          onPressed: () => context.go('/'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go to WWJD'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final reflection = _reflection!;
    final isGift = reflection.isGiftShare;
    final linkedPrayerId = _resolveSharedPrayerId(reflection);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isGift) _buildGiftWelcomeBanner(),
              if (!isGift && _showGuestWelcome) _buildGuestWelcomeBanner(),
              if (!isGift && !_showGuestWelcome && (_savedToJourney || _alreadyInJourney))
                _buildSavedBanner(),
              _buildAttributionBanner(reflection),
              Text(
                reflection.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              if (isGift) ...[
                const Text(
                  'Kingdom Challenge',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  reflection.importableDescription,
                  style: const TextStyle(fontSize: 16, height: 1.55),
                ),
                if (linkedPrayerId != null) ...[
                  const SizedBox(height: 16),
                  GiftPrayerLinkTile(prayerId: linkedPrayerId),
                ],
                if (reflection.personalNote?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'A note from the sharer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    reflection.personalNote!.trim(),
                    style: const TextStyle(fontSize: 16, height: 1.55, fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 28),
                AddSharedGiftButton(
                  title: reflection.title,
                  description: reflection.importableDescription,
                  attributionLine: sharedGiftAttributionLine(
                    shareAnonymously: reflection.shareAnonymously,
                    displayName: reflection.sharedByDisplayName,
                    favoriteSaint: reflection.favoriteSaint,
                  ),
                  shareSourceId: reflection.id,
                  linkedPrayerId: linkedPrayerId,
                ),
              ] else ...[
                const Text(
                  'Question',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  reflection.question,
                  style: const TextStyle(fontSize: 16, height: 1.55),
                ),
                const SizedBox(height: 24),
                const Text(
                  'WWJD Reflection',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                LinkedMarkdownBody(data: reflection.response),
                const SizedBox(height: 32),
                if (_showGuestWelcome || !ref.read(authServiceProvider).hasRegisteredAccount)
                  OutlinedButton.icon(
                    onPressed: _openAuthToSave,
                    icon: const Icon(Icons.login),
                    label: const Text('Log in or Register to save this to your journey'),
                  ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryMaroon,
                ),
                child: const Text('Continue to WWJD'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftWelcomeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.userBubble,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryMaroon.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Someone shared a Kingdom Challenge with you',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          SizedBox(height: 8),
          Text(
            'Read the challenge below. If it speaks to your heart, you may add it to your own Sharing My Gifts plan.',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributionBanner(SharedReflection reflection) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.parchmentDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            GiftSharePayload.brandName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            reflection.attributionLine,
            style: TextStyle(color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestWelcomeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.userBubble,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryMaroon.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Someone shared this reflection with you',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          SizedBox(height: 8),
          Text(
            'It is good that this wisdom was passed along. Read the question and response below. '
            'Log in or register when you are ready to save it to your journey.',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _savedToJourney
                  ? 'Saved to your journey in My History.'
                  : 'This reflection is already in your journey.',
              style: TextStyle(color: Colors.green.shade900),
            ),
          ),
        ],
      ),
    );
  }

  String? _resolveSharedPrayerId(SharedReflection reflection) {
    final stored = reflection.linkedPrayerId?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return PrayerGiftLink.detectPrayerId(
      title: reflection.title,
      description: reflection.importableDescription,
    );
  }
}
