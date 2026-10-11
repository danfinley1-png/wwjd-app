import 'package:flutter/material.dart';

import '../core/config.dart';

/// Logo + product name for app bars (no slogan in the title slot).
class WwjdBrandTitle extends StatelessWidget {
  const WwjdBrandTitle({
    super.key,
    this.logoSize = 54,
    this.titleStyle,
  });

  final double logoSize;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final title = titleStyle ??
        const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/wwjd_header.jpg',
            height: logoSize,
            width: logoSize,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              Icons.church,
              size: logoSize,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            AppConfig.mobileDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: title,
          ),
        ),
      ],
    );
  }
}
