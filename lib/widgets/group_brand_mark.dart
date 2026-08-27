import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/services/brand_image_service.dart';
import '../core/services/profile_photo_service.dart';

/// Circle avatar for organization branding (logo when set, otherwise initials).
/// Groups inherit the parent organization's logo.
///
/// Initials stay visible underneath so the circle is never empty. Logos load
/// as bytes (Cloud Function on web, Storage path on native) instead of
/// [NetworkImage], which blanks on CORS and stale download tokens.
class GroupBrandMark extends StatelessWidget {
  const GroupBrandMark({
    super.key,
    required this.groupName,
    this.logoUrl,
    this.orgId,
    this.size = 40,
  });

  final String groupName;
  final String? logoUrl;
  /// When set, load `organizations/{orgId}/logo.jpg` by path, ignoring token URLs.
  final String? orgId;
  final double size;

  static String initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  static Widget initialsCircle(String name, double size) {
    final initials = initialsFor(name);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primaryMaroon.withValues(alpha: 0.12),
      foregroundColor: AppColors.primaryMaroon,
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: size * 0.32,
          color: AppColors.primaryMaroon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    if (url == null || url.isEmpty) {
      return initialsCircle(groupName, size);
    }
    return _BrandLogoCircle(
      key: ValueKey('${orgId ?? ''}|$url|$size'),
      name: groupName,
      url: url,
      orgId: orgId,
      size: size,
    );
  }
}

class _BrandLogoCircle extends StatefulWidget {
  const _BrandLogoCircle({
    super.key,
    required this.name,
    required this.url,
    required this.size,
    this.orgId,
  });

  final String name;
  final String url;
  final String? orgId;
  final double size;

  @override
  State<_BrandLogoCircle> createState() => _BrandLogoCircleState();
}

class _BrandLogoCircleState extends State<_BrandLogoCircle> {
  Uint8List? _bytes;
  int _loadGen = 0;

  bool get _useByteLoader =>
      ProfilePhotoService.isFirebaseStorageUrl(widget.url);

  @override
  void initState() {
    super.initState();
    _bytes = BrandImageService.instance.cachedBytes(
      orgId: widget.orgId,
      url: widget.url,
    );
    if (_useByteLoader && (_bytes == null || _bytes!.isEmpty)) {
      _load();
    }
  }

  @override
  void didUpdateWidget(_BrandLogoCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.orgId != widget.orgId) {
      _bytes = BrandImageService.instance.cachedBytes(
        orgId: widget.orgId,
        url: widget.url,
      );
      if (_useByteLoader && (_bytes == null || _bytes!.isEmpty)) {
        _load();
      }
    }
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    final bytes = await BrandImageService.instance.load(
      orgId: widget.orgId,
      url: widget.url,
    );
    if (!mounted || gen != _loadGen) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.size;
    final initials = GroupBrandMark.initialsCircle(widget.name, widget.size);

    Widget? overlay;
    if (_bytes != null && _bytes!.isNotEmpty) {
      overlay = ClipOval(
        child: Image.memory(
          _bytes!,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    } else if (!_useByteLoader) {
      overlay = ClipOval(
        child: Image.network(
          widget.url,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox.shrink();
          },
        ),
      );
    }

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          initials,
          if (overlay != null) overlay,
        ],
      ),
    );
  }
}
