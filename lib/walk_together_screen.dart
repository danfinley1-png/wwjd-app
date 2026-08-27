import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../core/mobile_touch.dart';
import '../core/providers/app_providers.dart';
import '../core/providers/reflection_providers.dart';
import '../core/shared_gift_importer.dart';
import '../models/reflection_source.dart';
import '../core/walk_together_feed.dart';
import '../core/gift_share_payload.dart';
import '../models/walk_together_engagement.dart';
import '../models/walk_together_journey.dart';
import '../widgets/add_shared_gift_button.dart';
import '../widgets/linked_markdown_body.dart';
import '../widgets/reflection_composer.dart';
import '../widgets/walk_together_filter_bar.dart';
import '../widgets/auth_layout.dart';

class WalkTogetherScreen extends ConsumerWidget {
  const WalkTogetherScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WalkTogetherJourney journey, {
    VoidCallback? onDeleted,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete from Walk Together?'),
        content: SizedBox(
          width: double.maxFinite,
          child: Text(
            journey.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(walkTogetherServiceProvider).deleteJourney(journey.id);
      onDeleted?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journey removed from Walk Together')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  Future<void> _addJourneyReflection(
    BuildContext context,
    WidgetRef ref,
    WalkTogetherJourney journey,
  ) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to save private reflections.')),
        );
      }
      return;
    }

    final initialTitle = journey.title.trim().isNotEmpty
        ? 'Reflection: ${journey.title.trim()}'
        : 'Walk Together reflection';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _JourneyReflectionDialog(
        journeyTitle: journey.title,
        initialTitle: initialTitle,
        onSave: ({String? title, required String body}) async {
          final existing = await ref
              .read(reflectionServiceProvider)
              .findThreadForJourney(journey.id);
          if (existing != null) {
            await ref.read(reflectionServiceProvider).appendEntry(
                  threadId: existing.id,
                  body: body,
                );
          } else {
            await ref.read(reflectionServiceProvider).createReflection(
                  title: title,
                  body: body,
                  source: ReflectionSource.sharedJourney,
                  linkedJourneyId: journey.id,
                  linkedSourceTitle: journey.title,
                  linkedQuestionText: journey.question,
                );
          }
        },
      ),
    );
  }

  Future<void> _toggleSaved(
    BuildContext context,
    WidgetRef ref,
    WalkTogetherJourney journey,
  ) async {
    try {
      await ref
          .read(walkTogetherEngagementServiceProvider)
          .toggleSaved(journey.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  void _openJourney(
    BuildContext context,
    WidgetRef ref,
    WalkTogetherJourney journey,
    WalkTogetherEngagement engagement,
  ) {
    ref.read(walkTogetherEngagementServiceProvider).markRead(journey.id);

    final service = ref.read(walkTogetherServiceProvider);
    final canDelete = service.canDeleteJourney(journey);
    final isGift = journey.isGiftShare;
    final isSaved = engagement.isSaved(journey.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: true,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        journey.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: isSaved ? 'Remove bookmark' : 'Save post',
                      onPressed: () => _toggleSaved(context, ref, journey),
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_outline,
                        color: isSaved ? AppColors.gold : null,
                      ),
                    ),
                  ],
                ),
                if (isGift) ...[
                  const SizedBox(height: 4),
                  Text(
                    GiftSharePayload.brandName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    journey.attributionLine,
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  isGift ? 'Kingdom Challenge' : 'Question',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(journey.question),
                const SizedBox(height: 24),
                Text(
                  isGift ? 'Challenge' : 'WWJD Response',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                LinkedMarkdownBody(data: journey.response),
                if (isGift) ...[
                  const SizedBox(height: 24),
                  AddSharedGiftButton(
                    title: journey.title,
                    description: journey.importableDescription,
                    attributionLine: sharedGiftAttributionLine(
                      shareAnonymously: journey.shareAnonymously,
                      displayName: journey.sharedByDisplayName,
                      favoriteSaint: journey.favoriteSaint,
                    ),
                    shareSourceId: journey.id,
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _addJourneyReflection(context, ref, journey),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Add to My Reflections'),
                  ),
                ),
                const SizedBox(height: 32),
                if (canDelete) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(
                        context,
                        ref,
                        journey,
                        onDeleted: () => Navigator.pop(ctx),
                      ),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'Delete from Walk Together',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _upvoteJourney(
    BuildContext context,
    WidgetRef ref,
    WalkTogetherJourney journey,
  ) async {
    final session = ref.read(walkTogetherSessionProvider.notifier);
    if (session.hasUpvoted(journey.id)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already upvoted this journey this session.')),
        );
      }
      return;
    }

    try {
      await ref.read(walkTogetherServiceProvider).upvote(journey.id);
      session.markUpvoted(journey.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upvote: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journeysAsync = ref.watch(walkTogetherJourneysProvider);
    final engagementAsync = ref.watch(walkTogetherEngagementProvider);
    final tab = ref.watch(walkTogetherFeedTabProvider);
    final upvotedIds = ref.watch(walkTogetherSessionProvider);
    final walkTogetherService = ref.watch(walkTogetherServiceProvider);
    final engagement =
        engagementAsync.valueOrNull ?? WalkTogetherEngagement.empty;

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Walk Together')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Community Journeys\nSupport each other in faith.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          const WalkTogetherFilterBar(),
          Expanded(
            child: journeysAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load Walk Together:\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (journeys) {
                final filtered = filterWalkTogetherFeed(
                  journeys: journeys,
                  tab: tab,
                  engagement: engagement,
                );

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        walkTogetherEmptyMessage(
                          tab,
                          hideRead: engagement.hideRead,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final journey = filtered[index];
                    final questionPreview = journey.isGiftShare
                        ? 'Kingdom Challenge · ${journey.attributionLine}'
                        : (journey.question.length > 80
                            ? '${journey.question.substring(0, 80)}...'
                            : journey.question);
                    final hasUpvoted = upvotedIds.contains(journey.id);
                    final canDelete =
                        walkTogetherService.canDeleteJourney(journey);
                    final isSaved = engagement.isSaved(journey.id);
                    final isRead = engagement.isRead(journey.id);

                    return _WalkTogetherJourneyCard(
                      journey: journey,
                      questionPreview: questionPreview,
                      hasUpvoted: hasUpvoted,
                      isSaved: isSaved,
                      isRead: isRead,
                      canDelete: canDelete,
                      onOpen: () => _openJourney(context, ref, journey, engagement),
                      onToggleSaved: () => _toggleSaved(context, ref, journey),
                      onUpvote: hasUpvoted
                          ? null
                          : () => _upvoteJourney(context, ref, journey),
                      onDelete: canDelete
                          ? () => _confirmDelete(context, ref, journey)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkTogetherJourneyCard extends StatelessWidget {
  const _WalkTogetherJourneyCard({
    required this.journey,
    required this.questionPreview,
    required this.hasUpvoted,
    required this.isSaved,
    required this.isRead,
    required this.canDelete,
    required this.onOpen,
    required this.onToggleSaved,
    required this.onUpvote,
    this.onDelete,
  });

  final WalkTogetherJourney journey;
  final String questionPreview;
  final bool hasUpvoted;
  final bool isSaved;
  final bool isRead;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onToggleSaved;
  final VoidCallback? onUpvote;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      color: isRead ? AppColors.parchmentDark.withValues(alpha: 0.55) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                journey.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: isRead
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (journey.isGiftShare)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.card_giftcard,
                                  size: 16,
                                  color: AppColors.gold.withValues(alpha: 0.9),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          questionPreview,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                        if (isRead)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Already read',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_outline,
                    color: isSaved ? AppColors.gold : Colors.grey.shade600,
                  ),
                  tooltip: isSaved ? 'Remove bookmark' : 'Save post',
                  onPressed: onToggleSaved,
                  style: mobileIconButtonStyle(context),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete journey',
                    onPressed: onDelete,
                    style: mobileIconButtonStyle(context),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '${journey.upvotes}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        hasUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                        color: hasUpvoted ? Colors.grey : Colors.orange,
                      ),
                      tooltip: hasUpvoted
                          ? 'Already upvoted this session'
                          : 'Upvote',
                      onPressed: onUpvote,
                      style: mobileIconButtonStyle(context),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyReflectionDialog extends StatefulWidget {
  const _JourneyReflectionDialog({
    required this.journeyTitle,
    required this.initialTitle,
    required this.onSave,
  });

  final String journeyTitle;
  final String initialTitle;
  final Future<void> Function({String? title, required String body}) onSave;

  @override
  State<_JourneyReflectionDialog> createState() =>
      _JourneyReflectionDialogState();
}

class _JourneyReflectionDialogState extends State<_JourneyReflectionDialog> {
  bool _busy = false;

  Future<void> _submit({String? title, required String body}) async {
    setState(() => _busy = true);
    try {
      await widget.onSave(title: title, body: body);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to My Reflections')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAuthDialog(
      title: const Text('Add to My Reflections'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Private to you — only your words are saved.',
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              widget.journeyTitle,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 16),
            ReflectionComposer(
              showTitle: true,
              initialTitle: widget.initialTitle,
              submitLabel: 'Save reflection',
              busy: _busy,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
      actions: AuthDialogActions(actions: const []),
    );
  }
}
