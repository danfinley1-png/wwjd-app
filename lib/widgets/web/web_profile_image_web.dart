import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

int _imageViewId = 0;

/// Circular profile photo using a native HTML [img] tag (avoids Storage SDK + fetch CORS).
Widget buildWebProfileImage({
  required String imageUrl,
  required double size,
}) {
  return _WebProfileImage(imageUrl: imageUrl, size: size);
}

class _WebProfileImage extends StatefulWidget {
  const _WebProfileImage({
    required this.imageUrl,
    required this.size,
  });

  final String imageUrl;
  final double size;

  @override
  State<_WebProfileImage> createState() => _WebProfileImageState();
}

class _WebProfileImageState extends State<_WebProfileImage> {
  late final String _viewType = 'wwjd-profile-img-${_imageViewId++}';
  html.ImageElement? _img;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final wrapper = html.DivElement()
        ..style.width = '${widget.size}px'
        ..style.height = '${widget.size}px'
        ..style.borderRadius = '50%'
        ..style.overflow = 'hidden'
        ..style.backgroundColor = '#F5F0E8'
        ..style.border = '1px solid rgba(139, 30, 30, 0.35)';

      _img = html.ImageElement()
        ..src = widget.imageUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.display = 'block';

      wrapper.children.add(_img!);
      return wrapper;
    });
  }

  @override
  void didUpdateWidget(_WebProfileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _img?.src = widget.imageUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}

/// Placeholder circle matching profile image size.
Widget buildWebProfilePlaceholder({required double size}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.parchmentDark,
      shape: BoxShape.circle,
      border: Border.all(
        color: AppColors.primaryMaroon.withValues(alpha: 0.35),
      ),
    ),
    child: Icon(
      Icons.person_outline,
      size: size * 0.45,
      color: AppColors.primaryMaroon,
    ),
  );
}
