import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_colors.dart';
import '../core/content_guidance/content_guidance_models.dart';
import '../core/content_guidance/shared_content_gate.dart';
import '../core/gift_share_payload.dart';
import '../core/models/shareable_group.dart';
import '../core/providers/app_providers.dart';
import '../core/responsive_layout.dart';
import '../core/share_content.dart';
import '../core/user_text_input.dart';
import '../models/user_profile.dart';
import 'auth_layout.dart';
import 'edit_profile_dialog.dart';

/// Standard WWJD-DI share flow: confirm → options → copy / system / Walk Together.
class UnifiedShareFlow {
  UnifiedShareFlow._();

  static Future<void> show(
    BuildContext context, {
    required ShareContent content,
  }) async {
    final continueSharing = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(content.confirmTitle),
        content: SizedBox(
          width: responsiveDialogMaxWidth(ctx),
          child: const Text(
            'Please ensure no personal or confidential information is included.',
            style: TextStyle(fontSize: 15, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (continueSharing != true || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _ShareOptionsSheet(content: content),
    );
  }
}

class _ShareOptionsSheet extends ConsumerStatefulWidget {
  const _ShareOptionsSheet({required this.content});

  final ShareContent content;

  @override
  ConsumerState<_ShareOptionsSheet> createState() => _ShareOptionsSheetState();
}

class _ShareOptionsSheetState extends ConsumerState<_ShareOptionsSheet> {
  late final TextEditingController _noteController;
  bool _shareAnonymously = true;
  bool _forceAnonymousSharing = false;
  bool _isWorking = false;
  bool _appliedProfileDefault = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userGroupsServiceProvider).repairShareableGroupsIndex().catchError((_) {});
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  ShareContent get content => widget.content;

  String? get _accountEmail => ref.read(authServiceProvider).currentUser?.email;

  void _maybeApplyProfileDefault(UserProfile? profile) {
    if (_appliedProfileDefault || profile == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _appliedProfileDefault) return;
      setState(() {
        _shareAnonymously = profile.shareAnonymouslyByDefault;
        _appliedProfileDefault = true;
      });
    });
  }

  Future<UserProfile?> _loadProfile() async {
    final cached = ref.read(userProfileStreamProvider).valueOrNull;
    if (cached != null) return cached;
    return ref.read(userProfileServiceProvider).getCurrentUserProfile();
  }

  GiftSharePayload _giftPayload(
    UserProfile? profile, {
    required SharedContentInput fields,
  }) {
    return GiftSharePayload(
      title: fields.title ?? content.previewTitle,
      description: fields.response ?? content.response,
      personalNote: fields.personalNote ?? '',
      shareAnonymously: _shareAnonymously,
      displayName: _shareAnonymously ? null : profile?.effectiveDisplayName,
      favoriteSaint: _shareAnonymously ? null : profile?.favoriteSaint,
      linkedActivityId: content.linkedActivityId,
      linkedPrayerId: content.linkedPrayerId,
    );
  }

  SharedContentInput _shareInput() {
    return SharedContentInput(
      question: content.question,
      response: content.response,
      title: content.title,
      personalNote: _noteController.text,
    );
  }

  Future<SharedContentGateResult?> _prepareSharedContent(
    SharedContentChannel channel,
  ) async {
    final result = await sharedContentGate.prepare(
      context,
      input: _shareInput(),
      channel: channel,
    );
    if (result != null && result.requiresAnonymousSharing && mounted) {
      setState(() {
        _shareAnonymously = true;
        _forceAnonymousSharing = true;
      });
    }
    return result;
  }

  String _responseBodyFrom(SharedContentInput fields) {
    return ShareContent.bodyWithOptionalNote(
      body: fields.response ?? content.response,
      personalNote: fields.personalNote ?? '',
    );
  }

  Future<bool> _ensureAttributedProfile() async {
    var profile = await _loadProfile();
    if (profile?.hasDisplayName(_accountEmail) == true) return true;

    final saved = await EditProfileDialog.show(
      context,
      initialProfile: profile,
      requireDisplayName: true,
      showShareDefaultPreference: false,
      title: 'Set Up Your Profile',
      subtitle:
          'To share as your display name, choose how you would like to be known. '
          'Your favorite saint is optional.',
    );
    if (saved != true || !mounted) return false;

    profile = await ref.read(userProfileServiceProvider).getCurrentUserProfile();
    return profile?.hasDisplayName(_accountEmail) == true;
  }

  Future<UserProfile?> _profileForShare() async {
    if (_shareAnonymously) return _loadProfile();

    final ok = await _ensureAttributedProfile();
    if (!ok || !mounted) return null;

    final profile = await ref.read(userProfileServiceProvider).getCurrentUserProfile();
    if (profile?.hasDisplayName(_accountEmail) != true) return null;
    return profile;
  }

  Future<void> _ensureSignedIn() async {
    if (ref.read(authServiceProvider).currentUser == null) {
      await ref.read(authCoordinatorProvider).continueAsGuest();
    }
  }

  Future<String> _createShareId(
    UserProfile? profile, {
    required SharedContentInput fields,
  }) async {
    await _ensureSignedIn();
    final shareService = ref.read(shareServiceProvider);
    final uid = ref.read(authServiceProvider).currentUser?.uid;

    if (content.isGift) {
      return shareService.createGiftShare(
        payload: _giftPayload(profile, fields: fields),
        createdByUid: uid,
      );
    }

    final note = fields.personalNote?.trim() ?? '';
    final responseBody = _responseBodyFrom(fields);

    return shareService.createShare(
      question: fields.question ?? content.question,
      response: responseBody,
      title: fields.title ?? content.title,
      createdByUid: uid,
      extraFields: {
        'shareType': 'reflection',
        'shareAnonymously': _shareAnonymously,
        'sharedByDisplayName':
            _shareAnonymously ? null : profile?.effectiveDisplayName,
        'favoriteSaint':
            _shareAnonymously ? null : profile?.favoriteSaint?.trim(),
        'personalNote': note.isEmpty ? null : note,
        'brand': GiftSharePayload.brandName,
      },
    );
  }

  String _shareText(String url, UserProfile? profile, SharedContentInput fields) {
    if (content.isGift) {
      return _giftPayload(profile, fields: fields).formatShareText(url: url);
    }
    final shareContent = ShareContent.reflection(
      question: fields.question ?? content.question,
      response: fields.response ?? content.response,
      title: fields.title ?? content.title,
    );
    return ShareContent.formatShareText(
      content: shareContent,
      shareAnonymously: _shareAnonymously,
      displayName: profile?.effectiveDisplayName,
      favoriteSaint: profile?.favoriteSaint,
      personalNote: fields.personalNote ?? '',
      url: url,
    );
  }

  Future<String?> _prepareShareUrl(SharedContentChannel channel) async {
    if (_isWorking) return null;

    setState(() => _isWorking = true);
    try {
      final profile = await _profileForShare();
      if (profile == null && !_shareAnonymously) return null;

      final prepared = await _prepareSharedContent(channel);
      if (prepared == null || !mounted) return null;

      final shareId = await _createShareId(profile, fields: prepared.input);
      return ref.read(shareServiceProvider).buildShareUrl(shareId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create share link: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _copyLink() async {
    final url = await _prepareShareUrl(SharedContentChannel.shareLink);
    if (url == null || !mounted) return;

    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  Future<void> _systemShare() async {
    if (_isWorking) return;

    setState(() => _isWorking = true);
    try {
      final profile = await _profileForShare();
      if (profile == null && !_shareAnonymously) return;

      final prepared =
          await _prepareSharedContent(SharedContentChannel.systemShare);
      if (prepared == null || !mounted) return;

      final shareId = await _createShareId(profile, fields: prepared.input);
      final url = ref.read(shareServiceProvider).buildShareUrl(shareId);
      final text = _shareText(url, profile, prepared.input);

      await SharePlus.instance.share(
        ShareParams(
          subject: '${GiftSharePayload.brandName}: ${content.previewTitle}',
          text: text,
        ),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _shareToGroup(ShareableGroup group) async {
    if (_isWorking) return;

    setState(() => _isWorking = true);
    try {
      await _ensureSignedIn();
      final profile = await _profileForShare();
      if (profile == null && !_shareAnonymously) return;

      final prepared =
          await _prepareSharedContent(SharedContentChannel.groupShare);
      if (prepared == null || !mounted) return;

      final anonymous = _shareAnonymously || prepared.requiresAnonymousSharing;
      final groupShare = ref.read(groupShareServiceProvider);
      final shared = content.isGift
          ? await groupShare.shareGift(
              group: group,
              payload: _giftPayload(profile, fields: prepared.input),
            )
          : await groupShare.shareReflection(
              group: group,
              title: prepared.input.title ?? content.title,
              question: prepared.input.question ?? content.question,
              response: _responseBodyFrom(prepared.input),
              shareAnonymously: anonymous,
              sharedByDisplayName:
                  anonymous ? null : profile?.effectiveDisplayName,
              favoriteSaint: anonymous ? null : profile?.favoriteSaint,
              personalNote: prepared.input.personalNote,
            );

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(
            shared
                ? 'Shared to ${group.userFacingLabel}'
                : 'Could not share to ${group.userFacingLabel}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share to group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _shareToWalkTogether() async {
    if (_isWorking) return;

    setState(() => _isWorking = true);
    try {
      await _ensureSignedIn();
      final profile = await _profileForShare();
      if (profile == null && !_shareAnonymously) return;

      final prepared =
          await _prepareSharedContent(SharedContentChannel.walkTogether);
      if (prepared == null || !mounted) return;

      final anonymous = _shareAnonymously || prepared.requiresAnonymousSharing;
      final walkTogether = ref.read(walkTogetherServiceProvider);
      final added = content.isGift
          ? await walkTogether.addGiftJourney(
              _giftPayload(profile, fields: prepared.input),
            )
          : await walkTogether.addJourney(
              title: prepared.input.title ?? content.title,
              question: prepared.input.question ?? content.question,
              response: _responseBodyFrom(prepared.input),
              shareAnonymously: anonymous,
              sharedByDisplayName:
                  anonymous ? null : profile?.effectiveDisplayName,
              favoriteSaint:
                  anonymous ? null : profile?.favoriteSaint,
              personalNote: prepared.input.personalNote?.trim().isEmpty == true
                  ? null
                  : prepared.input.personalNote?.trim(),
            );

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      if (added) {
        final name = profile?.effectiveDisplayName;
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(
              anonymous
                  ? 'Shared anonymously to Walk Together'
                  : 'Shared as ${name ?? 'you'} to Walk Together',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 4),
            content: Text('This is already on Walk Together'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share to Walk Together: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _selectAttributedShare(UserProfile? profile) async {
    if (profile?.hasDisplayName(_accountEmail) == true) {
      setState(() => _shareAnonymously = false);
      return;
    }

    final ok = await _ensureAttributedProfile();
    if (ok && mounted) {
      setState(() => _shareAnonymously = false);
    }
  }

  String _attributionPreview(UserProfile? profile) {
    if (profile == null || _shareAnonymously) return '';
    final name = profile.effectiveDisplayName;
    final saint = profile.favoriteSaint?.trim();
    if (saint != null && saint.isNotEmpty) {
      return 'Sharing as $name · Friend of $saint';
    }
    return 'Sharing as $name';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileStreamProvider).valueOrNull;
    final shareableGroups =
        ref.watch(shareableGroupsProvider).valueOrNull ?? const [];
    final isSuperAdmin = ref.watch(isSuperAdminUserProvider).valueOrNull ?? false;
    _maybeApplyProfileDefault(profile);

    final canAttribute = profile?.hasDisplayName(_accountEmail) ?? false;
    final displayName = canAttribute ? profile!.effectiveDisplayName : '';
    final attributionPreview = _attributionPreview(profile);
    final noteHint = content.isGift
        ? 'I have found this Gift to be an inspirational part of my faith journey.'
        : 'This reflection has been meaningful on my faith journey.';

    return ResponsiveAuthDialog(
      title: const Text('Share Options'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.parchmentDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.previewTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content.previewBody,
                  style: const TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          UserTextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Personal note (optional)',
              hintText: noteHint,
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          const Text(
            'How would you like to share?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share anonymously'),
            subtitle: Text(
              _forceAnonymousSharing
                  ? 'Required for safety and privacy with this share'
                  : 'Your name will not appear',
            ),
            value: true,
            groupValue: _shareAnonymously,
            onChanged: _isWorking
                ? null
                : (_) => setState(() => _shareAnonymously = true),
          ),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            title: Text(
              canAttribute
                  ? 'Share as $displayName'
                  : 'Share as [Display Name]',
            ),
            subtitle: Text(
              _forceAnonymousSharing
                  ? 'Not available for this share'
                  : canAttribute
                      ? 'Your display name will appear on the share'
                      : 'Tap to set a display name before sharing',
            ),
            value: false,
            groupValue: _shareAnonymously,
            onChanged: _isWorking || _forceAnonymousSharing
                ? null
                : (_) => _selectAttributedShare(profile),
          ),
          if (attributionPreview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryMaroon.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryMaroon.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                attributionPreview,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryMaroon.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            GiftSharePayload.brandTagline,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: AuthDialogActions(
        actions: [
          TextButton(
            onPressed: _isWorking ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _isWorking ? null : _copyLink,
            icon: _isWorking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link),
            label: const Text('Copy Link'),
          ),
          OutlinedButton.icon(
            onPressed: _isWorking ? null : _systemShare,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share via System'),
          ),
          if (content.allowWalkTogether)
            OutlinedButton.icon(
              onPressed: _isWorking ? null : _shareToWalkTogether,
              icon: const Icon(Icons.people_outline),
              label: const Text('Share to Walk Together'),
            ),
          if (shareableGroups.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isSuperAdmin ? 'Share to a group' : 'Share to your group',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            for (final group in shareableGroups)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _isWorking ? null : () => _shareToGroup(group),
                  icon: const Icon(Icons.groups_outlined),
                  label: Text(group.userFacingLabel),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
