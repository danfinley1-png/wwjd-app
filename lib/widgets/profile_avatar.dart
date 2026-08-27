import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/platform_utils.dart';
import '../core/services/profile_photo_service.dart';
import 'web/web_profile_image_stub.dart'
    if (dart.library.html) 'web/web_profile_image_web.dart';

/// Displays a user's profile photo or a gentle fallback icon.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.photoUrl,
    this.radius = 28,
    this.onTap,
    this.cacheBustMs,
    this.loadFromStorageWhenEmpty = false,
    this.previewBytes,
  });

  final String? photoUrl;
  final double radius;
  final VoidCallback? onTap;
  /// Optional timestamp (e.g. profile `updatedAt`) to bypass browser cache.
  final int? cacheBustMs;
  /// When true, loads `users/{uid}/profile.jpg` even if Firestore has no photoURL.
  final bool loadFromStorageWhenEmpty;
  /// Optional in-memory preview (e.g. immediately after upload).
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    final trimmed = photoUrl?.trim();
    final hasUrl = trimmed != null && trimmed.isNotEmpty;
    final networkUrl = hasUrl
        ? ProfilePhotoService.displayUrl(trimmed, cacheBustMs: cacheBustMs)
        : null;

    Widget avatar;
    if (previewBytes != null && previewBytes!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.parchmentDark,
        backgroundImage: MemoryImage(previewBytes!),
      );
    } else if (kIsWeb && isMobileWeb) {
      // iOS Safari: NetworkImage and HtmlElementView fail on Storage URLs — load via proxy.
      avatar = _StorageProfileAvatar(
        photoUrl: trimmed,
        radius: radius,
        loadFromPathWhenEmpty: loadFromStorageWhenEmpty || !hasUrl,
      );
    } else if (kIsWeb && networkUrl != null && !isMobileWeb) {
      // Desktop web only — HtmlElementView breaks on iPhone/mobile Safari.
      avatar = KeyedSubtree(
        key: ValueKey(networkUrl),
        child: buildWebProfileImage(imageUrl: networkUrl, size: radius * 2),
      );
    } else if (hasUrl && ProfilePhotoService.isFirebaseStorageUrl(trimmed)) {
      avatar = _NetworkProfileAvatar(
        photoUrl: networkUrl ?? trimmed,
        radius: radius,
      );
    } else if (loadFromStorageWhenEmpty && !kIsWeb) {
      avatar = _StorageProfileAvatar(
        photoUrl: trimmed,
        radius: radius,
        loadFromPathWhenEmpty: true,
      );
    } else if (networkUrl != null) {
      avatar = _NetworkProfileAvatar(
        photoUrl: networkUrl,
        radius: radius,
      );
    } else {
      avatar = _fallbackAvatar(radius);
    }

    if (onTap != null) {
      avatar = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: CircleBorder(
            side: BorderSide(
              color: AppColors.primaryMaroon.withValues(alpha: 0.35),
            ),
          ),
          child: avatar,
        ),
      );
    }

    return avatar;
  }

  static Widget _fallbackAvatar(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.parchmentDark,
      child: Icon(
        Icons.person_outline,
        size: radius * 0.9,
        color: AppColors.primaryMaroon,
      ),
    );
  }
}

/// Loads profile photos through the Firebase Storage SDK (works on web where
/// [NetworkImage] often fails due to CORS even when upload succeeded).
class _StorageProfileAvatar extends StatefulWidget {
  const _StorageProfileAvatar({
    required this.photoUrl,
    required this.radius,
    this.loadFromPathWhenEmpty = false,
  });

  final String? photoUrl;
  final double radius;
  final bool loadFromPathWhenEmpty;

  @override
  State<_StorageProfileAvatar> createState() => _StorageProfileAvatarState();
}

class _StorageProfileAvatarState extends State<_StorageProfileAvatar> {
  final _photoService = ProfilePhotoService();
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_StorageProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl ||
        oldWidget.loadFromPathWhenEmpty != widget.loadFromPathWhenEmpty) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      Uint8List? bytes;
      if (widget.loadFromPathWhenEmpty && (widget.photoUrl == null || widget.photoUrl!.isEmpty)) {
        bytes = await _photoService.loadBytesForCurrentUser();
      } else {
        bytes = await _photoService.loadProfileBytes(photoUrl: widget.photoUrl);
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _failed = bytes == null || bytes.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null && _bytes!.isNotEmpty) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: AppColors.parchmentDark,
        backgroundImage: MemoryImage(_bytes!),
      );
    }

    if (_failed) {
      return ProfileAvatar._fallbackAvatar(widget.radius);
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.parchmentDark,
      child: SizedBox(
        width: widget.radius,
        height: widget.radius,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primaryMaroon.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _NetworkProfileAvatar extends StatefulWidget {
  const _NetworkProfileAvatar({
    required this.photoUrl,
    required this.radius,
  });

  final String photoUrl;
  final double radius;

  @override
  State<_NetworkProfileAvatar> createState() => _NetworkProfileAvatarState();
}

class _NetworkProfileAvatarState extends State<_NetworkProfileAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(_NetworkProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return ProfileAvatar._fallbackAvatar(widget.radius);
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.parchmentDark,
      backgroundImage: NetworkImage(widget.photoUrl),
      onBackgroundImageError: (_, __) {
        if (mounted) setState(() => _failed = true);
      },
      child: null,
    );
  }
}
