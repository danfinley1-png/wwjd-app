import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../core/app_colors.dart';

import '../core/providers/app_providers.dart';

import '../core/responsive_layout.dart';

import '../models/walk_together_engagement.dart';



class WalkTogetherFilterBar extends ConsumerWidget {

  const WalkTogetherFilterBar({super.key});



  FilterChip _tabChip({

    required BuildContext context,

    required String label,

    required bool selected,

    required VoidCallback onTap,

  }) {

    return FilterChip(

      label: Text(label),

      selected: selected,

      onSelected: (_) => onTap(),

      materialTapTargetSize: MaterialTapTargetSize.padded,

      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),

      selectedColor: AppColors.primaryMaroon.withValues(alpha: 0.14),

      checkmarkColor: AppColors.primaryMaroon,

      labelStyle: TextStyle(

        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,

        color: selected ? AppColors.primaryMaroon : AppColors.textSecondary,

      ),

      side: BorderSide(

        color: selected

            ? AppColors.primaryMaroon.withValues(alpha: 0.45)

            : Colors.grey.shade400,

      ),

    );

  }



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final tab = ref.watch(walkTogetherFeedTabProvider);

    final engagement = ref.watch(walkTogetherEngagementProvider).valueOrNull ??

        WalkTogetherEngagement.empty;

    final compact = isCompactWidth(context);



    final tabChips = [

      for (final feedTab in WalkTogetherFeedTab.values)

        Padding(

          padding: const EdgeInsets.only(right: 8, bottom: 8),

          child: _tabChip(

            context: context,

            label: feedTab.label,

            selected: tab == feedTab,

            onTap: () {

              ref.read(walkTogetherFeedTabProvider.notifier).state = feedTab;

            },

          ),

        ),

    ];



    return Material(

      color: AppColors.parchmentDark,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Padding(

            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),

            child: compact

                ? Wrap(children: tabChips)

                : SingleChildScrollView(

                    scrollDirection: Axis.horizontal,

                    child: Row(children: tabChips),

                  ),

          ),

          Padding(

            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),

            child: FilterChip(

              avatar: Icon(

                engagement.hideRead

                    ? Icons.visibility_off_outlined

                    : Icons.visibility_outlined,

                size: 18,

                color: engagement.hideRead

                    ? AppColors.primaryMaroon

                    : AppColors.textSecondary,

              ),

              label: const Text('Hide already read'),

              selected: engagement.hideRead,

              materialTapTargetSize: MaterialTapTargetSize.padded,

              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),

              onSelected: (selected) async {

                try {

                  await ref

                      .read(walkTogetherEngagementServiceProvider)

                      .setHideRead(selected);

                } catch (e) {

                  if (context.mounted) {

                    ScaffoldMessenger.of(context).showSnackBar(

                      SnackBar(content: Text('$e')),

                    );

                  }

                }

              },

              selectedColor: AppColors.primaryMaroon.withValues(alpha: 0.12),

              checkmarkColor: AppColors.primaryMaroon,

              labelStyle: TextStyle(

                color: engagement.hideRead

                    ? AppColors.primaryMaroon

                    : AppColors.textSecondary,

              ),

              side: BorderSide(

                color: engagement.hideRead

                    ? AppColors.primaryMaroon.withValues(alpha: 0.45)

                    : Colors.grey.shade400,

              ),

            ),

          ),

          const Divider(height: 1),

        ],

      ),

    );

  }

}


