import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../core/providers/tts_providers.dart';
import '../core/services/tts/tts_voice_preference.dart';

/// Profile setting for read-aloud voice (TTS only — not AI personality).
class ReadAloudVoiceSetting extends ConsumerWidget {
  const ReadAloudVoiceSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferenceAsync = ref.watch(ttsPreferenceProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    color: AppColors.primaryMaroon.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Read-aloud voice',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Text(
                'For prayers and Listen buttons only. Does not change written responses.',
                style: TextStyle(color: Colors.grey, height: 1.45),
              ),
            ),
            preferenceAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Could not load voice preference.'),
              ),
              data: (TtsVoicePreference selected) => Column(
                children: TtsVoicePreference.values.map((option) {
                  return RadioListTile<TtsVoicePreference>(
                    value: option,
                    groupValue: selected,
                    title: Text(option.label),
                    subtitle: Text(option.description),
                    onChanged: (value) async {
                      if (value == null) return;
                      await ref
                          .read(ttsPreferenceProvider.notifier)
                          .setPreference(value);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
