import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_colors.dart';
import '../core/platform_utils.dart';
import '../core/mobile_touch.dart';
import '../core/providers/app_providers.dart';
import '../core/services/profile_photo_service.dart';
import 'profile_avatar.dart';

/// Tap-to-change profile photo with gallery, optional camera, and remove.
class ProfilePhotoEditor extends ConsumerStatefulWidget {
  const ProfilePhotoEditor({
    super.key,
    this.photoUrl,
    this.compact = false,
  });

  final String? photoUrl;
  final bool compact;

  @override
  ConsumerState<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends ConsumerState<ProfilePhotoEditor> {
  bool _busy = false;
  String? _justUploadedUrl;
  Uint8List? _previewBytes;
  bool _syncAttempted = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncStoragePhotoUrl());
    }
  }

  Future<void> _syncStoragePhotoUrl() async {
    if (_syncAttempted || kIsWeb) return;
    _syncAttempted = true;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final url = await ref
          .read(userProfileServiceProvider)
          .syncPhotoUrlFromStorage();
      if (!mounted) return;
      if (url != null) {
        setState(() => _justUploadedUrl = url);
      } else {
        final bytes = await ref
            .read(userProfileServiceProvider)
            .photoService
            .loadBytesForCurrentUser();
        if (bytes != null && bytes.isNotEmpty && mounted) {
          setState(() => _previewBytes = bytes);
        }
      }
    } catch (_) {
      // Non-fatal on native.
    }
  }

  Future<void> _uploadPicked(ProfilePhotoPick picked) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sign in with an account (not guest) to save a profile photo.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _busy = true;
      _previewBytes = picked.bytes;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading profile photo…'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final url = await ref
          .read(userProfileServiceProvider)
          .uploadPickedProfilePhoto(picked);
      if (!mounted) return;
      if (url != null) {
        setState(() {
          _justUploadedUrl = url;
          _previewBytes = picked.bytes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo saved.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication error')),
        );
      }
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

  Future<void> _pickAndUploadWeb() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sign in with an account (not guest) to save a profile photo.',
          ),
        ),
      );
      return;
    }

    try {
      final picked = await ref
          .read(userProfileServiceProvider)
          .photoService
          .pickGalleryViaFilePicker();
      if (!mounted || picked == null) return;
      await _uploadPicked(picked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open photo: $e')),
        );
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sign in with an account (not guest) to save a profile photo.',
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final url = await ref
          .read(userProfileServiceProvider)
          .uploadProfilePhoto(source: source);
      if (!mounted) return;
      if (url != null) {
        final bytes = await ref
            .read(userProfileServiceProvider)
            .photoService
            .loadBytesForCurrentUser();
        setState(() {
          _justUploadedUrl = url;
          if (bytes != null && bytes.isNotEmpty) _previewBytes = bytes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo saved.')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image was selected')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication error')),
        );
      }
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

  Future<void> _removePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text(
          'Your profile picture will be removed. You can add a new one anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(userProfileServiceProvider).removeProfilePhoto();
      if (mounted) {
        setState(() {
          _justUploadedUrl = null;
          _previewBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo removed')),
        );
      }
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

  Future<void> _showOptions() async {
    if (_busy) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
        final hasPhoto =
            (widget.photoUrl != null && widget.photoUrl!.trim().isNotEmpty) ||
                _justUploadedUrl != null ||
                _previewBytes != null;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
                if (ProfilePhotoService.supportsCamera)
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Take a photo'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickPhoto(ImageSource.camera);
                    },
                  ),
                if (hasPhoto)
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
                    title: Text(
                      'Remove photo',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _removePhoto();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _hasPhoto {
    final profile = ref.watch(userProfileStreamProvider).maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );
    final photoUrl = _justUploadedUrl ?? profile?.photoUrl ?? widget.photoUrl;
    return (photoUrl != null && photoUrl.trim().isNotEmpty) ||
        (_previewBytes != null && _previewBytes!.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileStreamProvider).maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );
    final photoUrl = _justUploadedUrl ?? profile?.photoUrl ?? widget.photoUrl;
    final cacheBustMs = profile?.updatedAt?.millisecondsSinceEpoch ??
        (_justUploadedUrl != null ? DateTime.now().millisecondsSinceEpoch : null);
    final radius = widget.compact ? 24.0 : 44.0;

    if (kIsWeb) {
      return Column(
        children: [
          ProfileAvatar(
            photoUrl: photoUrl,
            cacheBustMs: cacheBustMs,
            previewBytes: _previewBytes,
            loadFromStorageWhenEmpty: isMobileWeb,
            radius: radius,
          ),
          if (!widget.compact) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _pickAndUploadWeb,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: Text(_hasPhoto ? 'Choose new photo' : 'Choose photo'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'JPG or PNG, under 5 MB',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryMaroon.withValues(alpha: 0.7),
              ),
            ),
            if (_hasPhoto)
              TextButton(
                onPressed: _busy ? null : _removePhoto,
                style: mobileTextButtonStyle(context).copyWith(
                  foregroundColor: WidgetStatePropertyAll(Colors.red.shade700),
                ),
                child: const Text('Remove photo'),
              ),
          ],
        ],
      );
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            ProfileAvatar(
              photoUrl: photoUrl,
              cacheBustMs: cacheBustMs,
              previewBytes: _previewBytes,
              loadFromStorageWhenEmpty: true,
              radius: radius,
              onTap: _busy ? null : _showOptions,
            ),
            if (_busy)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
              )
            else
              Material(
                color: AppColors.primaryMaroon,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _showOptions,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: widget.compact ? 16 : 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (!widget.compact) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: _busy ? null : _showOptions,
            style: mobileTextButtonStyle(context),
            child: Text(
              _hasPhoto ? 'Change profile photo' : 'Add profile photo',
            ),
          ),
        ],
      ],
    );
  }
}
