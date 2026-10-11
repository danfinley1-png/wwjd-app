import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/config.dart';
import '../core/responsive_layout.dart';

/// Full-width purpose copy directly under the app bar (Home, saint watch).
class WwjdPurposeBar extends StatelessWidget {
  const WwjdPurposeBar({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 380;
    final style = TextStyle(
      fontSize: narrow ? 15 : 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColors.primaryMaroon,
    );

    return Material(
      color: AppColors.parchment,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          responsiveHorizontalPadding(context).left,
          10,
          responsiveHorizontalPadding(context).right,
          10,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.primaryMaroon.withValues(alpha: 0.12),
            ),
          ),
        ),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppConfig.purposeLineOne, style: style),
                  Text(AppConfig.purposeLineTwo, style: style),
                ],
              )
            : Text(
                '${AppConfig.purposeLineOne} ${AppConfig.purposeLineTwo}',
                style: style,
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}
