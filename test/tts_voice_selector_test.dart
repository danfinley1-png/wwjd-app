import 'package:flutter_test/flutter_test.dart';
import 'package:wwjd_app/core/services/tts/tts_voice_config.dart';
import 'package:wwjd_app/core/services/tts/tts_voice_preference.dart';
import 'package:wwjd_app/core/services/tts/tts_voice_selector.dart';

void main() {
  group('TtsVoiceSelector', () {
    final voices = [
      {'name': 'Microsoft David Desktop', 'locale': 'en-US'},
      {'name': 'Microsoft Zira Desktop', 'locale': 'en-US'},
      {'name': 'Google Deutsch', 'locale': 'de-DE'},
    ];

    test('selects pastoral male voice by hints', () {
      final selected = TtsVoiceSelector.selectVoice(
        voices: voices,
        preference: TtsVoicePreference.malePastoral,
        config: TtsVoiceConfig.defaults,
      );
      expect(selected?['name'], contains('David'));
    });

    test('selects female voice by hints', () {
      final selected = TtsVoiceSelector.selectVoice(
        voices: voices,
        preference: TtsVoicePreference.female,
        config: TtsVoiceConfig.defaults,
      );
      expect(selected?['name'], contains('Zira'));
    });

    test('prefers exact remote voice name when configured', () {
      final config = TtsVoiceConfig(
        speechRate: 0.85,
        pitchMale: 0.95,
        pitchFemale: 1.05,
        maleVoiceHints: ['david'],
        femaleVoiceHints: ['zira'],
        maleVoiceNames: ['Microsoft Zira Desktop'],
        femaleVoiceNames: const [],
      );
      final selected = TtsVoiceSelector.selectVoice(
        voices: voices,
        preference: TtsVoicePreference.malePastoral,
        config: config,
      );
      expect(selected?['name'], 'Microsoft Zira Desktop');
    });
  });

  group('TtsVoiceConfig', () {
    test('falls back to defaults for empty remote map', () {
      expect(TtsVoiceConfig.fromMap(null).speechRate, 0.85);
    });

    test('reads remote speech rate without slowing below default cadence', () {
      final config = TtsVoiceConfig.fromMap({'speechRate': 0.85});
      expect(config.speechRate, 0.85);
    });
  });
}
