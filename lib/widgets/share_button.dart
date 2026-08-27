import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../core/app_colors.dart';

import '../core/mobile_touch.dart';

import '../core/share_content.dart';

import 'unified_share_flow.dart';



class ShareButton extends ConsumerWidget {

  final String question;

  final String response;

  final String? title;

  final String? giftDescription;

  final bool showLabel;

  final String? linkedActivityId;

  final String? linkedPrayerId;

  final bool isGiftActivity;



  const ShareButton({

    super.key,

    required this.question,

    required this.response,

    this.title,

    this.giftDescription,

    this.showLabel = false,

    this.linkedActivityId,

    this.linkedPrayerId,

    this.isGiftActivity = false,

  });



  void _openShare(BuildContext context) {

    final content = isGiftActivity

        ? ShareContent.gift(

            title: title ?? question.replaceFirst('Activity: ', ''),

            description: giftDescription ?? response,

            linkedActivityId: linkedActivityId,

            linkedPrayerId: linkedPrayerId,

          )

        : ShareContent.reflection(

            question: question,

            response: response,

            title: title,

          );



    UnifiedShareFlow.show(context, content: content);

  }



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    if (showLabel) {

      return TextButton.icon(

        onPressed: () => _openShare(context),

        icon: const Icon(Icons.share_outlined, size: 20),

        label: const Text('Share'),

        style: TextButton.styleFrom(

          foregroundColor: AppColors.primaryMaroon,

        ).merge(mobileTextButtonStyle(context)),

      );

    }



    return IconButton(

      icon: const Icon(Icons.share_outlined, size: 22),

      tooltip: 'Share',

      onPressed: () => _openShare(context),

      style: mobileIconButtonStyle(context),

    );

  }

}


