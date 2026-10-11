import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/pastoral_theme.dart';
import '../../models/product_feedback.dart';
import '../providers/admin_providers.dart';

/// Overall Admin review of product-issue feedback (not spiritual content).
class ProductFeedbackScreen extends ConsumerWidget {
  const ProductFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
    if (!isSuperAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Feedback')),
        body: const Center(
          child: Text('Overall Admin access required.'),
        ),
      );
    }

    final feedbackAsync = ref.watch(productFeedbackListProvider);
    final votesAsync = ref.watch(replyHelpfulVotesProvider);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Product issues sent from My Profile. This list is separate from '
            'question themes and My Reflections. Group leaders are not emailed.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.45),
          ),
          const SizedBox(height: 16),
          feedbackAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Could not load feedback: $e'),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No product feedback yet.'),
                );
              }
              return Column(
                children: [
                  for (final item in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${dateFormat.format(item.createdAt.toLocal())} · ${item.type.label}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(item.text, style: const TextStyle(height: 1.4)),
                            const SizedBox(height: 8),
                            Text(
                              item.contactLabel,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (item.email != null && item.email!.trim().isNotEmpty)
                              Text(
                                item.email!,
                                style: TextStyle(color: Colors.grey.shade800),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Reply helpful (flag and theme only — no question text)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          votesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('Could not load helpful votes: $e'),
            data: (votes) {
              if (votes.isEmpty) {
                return const Text('No reply votes yet.');
              }
              final yes = votes.where((v) => v.helpful).length;
              final no = votes.length - yes;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yes $yes · No $no'),
                  const SizedBox(height: 8),
                  for (final vote in votes.take(50))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${dateFormat.format(vote.createdAt.toLocal())} · '
                        '${vote.helpful ? 'Yes' : 'No'}'
                        '${vote.theme == null ? '' : ' · ${_themeLabel(vote.theme)}'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _themeLabel(String? value) {
    if (value == null || value.isEmpty) return '';
    return pastoralThemeFromFirestore(value).label;
  }
}
