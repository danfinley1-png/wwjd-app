import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../core/providers/app_providers.dart';
import '../core/user_text_input.dart';
import '../models/user_profile.dart';
import '../widgets/auth_layout.dart';
import '../widgets/profile_photo_editor.dart';

/// Minimal profile editor — display name (required) and favorite saint (optional).
class EditProfileDialog extends ConsumerStatefulWidget {
  const EditProfileDialog({
    super.key,
    this.initialProfile,
    this.requireDisplayName = false,
    this.showShareDefaultPreference = true,
    this.title = 'Edit Profile',
    this.subtitle,
  });

  final UserProfile? initialProfile;
  final bool requireDisplayName;
  final bool showShareDefaultPreference;
  final String title;
  final String? subtitle;

  static Future<bool?> show(
    BuildContext context, {
    UserProfile? initialProfile,
    bool requireDisplayName = false,
    bool showShareDefaultPreference = true,
    String title = 'Edit Profile',
    String? subtitle,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EditProfileDialog(
        initialProfile: initialProfile,
        requireDisplayName: requireDisplayName,
        showShareDefaultPreference: showShareDefaultPreference,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _saintController;
  late bool _shareAnonymouslyByDefault;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _saintController = TextEditingController();
    _shareAnonymouslyByDefault = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final profile = widget.initialProfile;
    final accountEmail = ref.read(authServiceProvider).currentUser?.email;
    final existingName = profile?.displayName?.trim();
    if (UserProfile.isValidDisplayName(existingName, accountEmail: accountEmail)) {
      _nameController.text = existingName!;
    } else {
      final suggested =
          ref.read(userProfileServiceProvider).suggestedDisplayName();
      _nameController.text = suggested ?? '';
    }
    _saintController.text = profile?.favoriteSaint ?? '';
    _shareAnonymouslyByDefault = profile?.shareAnonymouslyByDefault ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _saintController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final accountEmail = ref.read(authServiceProvider).currentUser?.email;
    if (!UserProfile.isValidDisplayName(name, accountEmail: accountEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a display name (not your email address)'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(userProfileServiceProvider).upsertProfile(
            displayName: name,
            favoriteSaint: _saintController.text.trim(),
            shareAnonymouslyByDefault: widget.showShareDefaultPreference
                ? _shareAnonymouslyByDefault
                : null,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAuthDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ProfilePhotoEditor(
              photoUrl: widget.initialProfile?.photoUrl,
              compact: true,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              style: TextStyle(color: Colors.grey.shade700, height: 1.45),
            ),
            const SizedBox(height: 16),
          ],
          UserTextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Display Name *',
              hintText: 'How you appear when sharing',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          UserTextField(
            controller: _saintController,
            decoration: const InputDecoration(
              labelText: 'Favorite Saint (optional)',
              hintText: 'e.g. St. Francis of Assisi',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),
          if (widget.showShareDefaultPreference)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share anonymously by default'),
              subtitle: const Text(
                'You can still choose to share with your display name each time.',
                style: TextStyle(fontSize: 12.5),
              ),
              value: _shareAnonymouslyByDefault,
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _shareAnonymouslyByDefault = value),
            ),
          if (widget.requireDisplayName)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'A display name is required before sharing with attribution.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.primaryMaroon.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
      actions: AuthDialogActions(
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
