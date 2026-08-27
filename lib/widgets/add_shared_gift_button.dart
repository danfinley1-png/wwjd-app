import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../core/providers/app_providers.dart';
import '../core/shared_gift_importer.dart';

/// Adds a shared Kingdom Challenge to the current user's Gifts Plan.
class AddSharedGiftButton extends ConsumerStatefulWidget {
  const AddSharedGiftButton({
    super.key,
    required this.title,
    required this.description,
    required this.attributionLine,
    this.shareSourceId,
    this.frequency = 'Daily',
    this.linkedPrayerId,
  });

  final String title;
  final String description;
  final String attributionLine;
  final String? shareSourceId;
  final String frequency;
  final String? linkedPrayerId;

  @override
  ConsumerState<AddSharedGiftButton> createState() => _AddSharedGiftButtonState();
}

class _AddSharedGiftButtonState extends ConsumerState<AddSharedGiftButton> {
  bool _isAdding = false;
  bool _added = false;
  bool _duplicate = false;

  Future<void> _addToPlan() async {
    if (_isAdding || _added) return;

    setState(() => _isAdding = true);
    try {
      if (ref.read(authServiceProvider).currentUser == null) {
        await ref.read(authCoordinatorProvider).continueAsGuest();
      }

      final result = await importSharedGiftToPlan(
        ref: ref,
        giftService: ref.read(giftServiceProvider),
        title: widget.title,
        description: widget.description,
        sharedByLine: widget.attributionLine,
        shareSourceId: widget.shareSourceId,
        frequency: widget.frequency,
        linkedPrayerId: widget.linkedPrayerId,
      );

      if (!mounted) return;
      setState(() {
        _added = result.added;
        _duplicate = result.duplicate;
      });

      final message = result.added
          ? 'Added to Sharing My Gifts'
          : result.duplicate
              ? 'This Gift is already in your plan'
              : 'Could not add to your plan';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result.added ? AppColors.success : null,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add Gift: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _added
        ? (_duplicate ? 'Already in My Gifts' : 'Added to My Gifts')
        : 'Add to My Gifts Plan';

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: (_isAdding || (_added && !_duplicate)) ? null : _addToPlan,
        icon: _isAdding
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(_added ? Icons.check_circle_outline : Icons.card_giftcard),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryMaroon,
        ),
      ),
    );
  }
}
