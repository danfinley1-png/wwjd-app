import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../core/mobile_touch.dart';

import '../core/responsive_layout.dart';

import 'share_button.dart';



/// Horizontal action bar for share/delete on compact screens (My History, Gifts).

/// Horizontal action bar for share/delete on compact screens (My History, Gifts).
/// Keep outside the card body InkWell to avoid tap conflicts on mobile web.

class ShareActionsBar extends ConsumerWidget {

  const ShareActionsBar({

    super.key,

    required this.question,

    required this.response,

    this.title,

    this.giftDescription,

    this.onDelete,

    this.deleteTooltip = 'Remove',

    this.linkedActivityId,

    this.linkedPrayerId,

    this.isGiftActivity = false,

  });



  final String question;

  final String response;

  final String? title;

  final String? giftDescription;

  final VoidCallback? onDelete;

  final String deleteTooltip;

  final String? linkedActivityId;

  final String? linkedPrayerId;

  final bool isGiftActivity;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final compact = isCompactWidth(context);

    final textStyle = mobileTextButtonStyle(context);

    final iconStyle = mobileIconButtonStyle(context);



    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 4),

      child: Wrap(

        alignment: WrapAlignment.end,

        spacing: 4,

        runSpacing: 4,

        children: [

          if (onDelete != null)

            compact

                ? TextButton.icon(

                    onPressed: onDelete,

                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),

                    label: const Text('Remove'),

                    style: textStyle,

                  )

                : IconButton(

                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),

                    tooltip: deleteTooltip,

                    onPressed: onDelete,

                    style: iconStyle,

                  ),

          ShareButton(

            question: question,

            response: response,

            title: title,

            giftDescription: giftDescription,

            showLabel: compact,

            linkedActivityId: linkedActivityId,

            linkedPrayerId: linkedPrayerId,

            isGiftActivity: isGiftActivity,

          ),

        ],

      ),

    );

  }

}


