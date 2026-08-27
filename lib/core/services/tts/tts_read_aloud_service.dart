import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_config_service.dart';
import 'tts_preference_store.dart';
import 'tts_voice_config.dart';
import 'tts_voice_preference.dart';
import 'tts_voice_selector.dart';

/// Shared text-to-speech for prayers, chat read-aloud, and other listen features.
class TtsReadAloudService {
  TtsReadAloudService({
    FlutterTts? tts,
    TtsPreferenceStore? preferenceStore,
    TtsConfigService? configService,
  })  : _tts = tts ?? FlutterTts(),
        _preferenceStore = preferenceStore ?? TtsPreferenceStore(),
        _configService = configService ?? TtsConfigService();

  final FlutterTts _tts;
  final TtsPreferenceStore _preferenceStore;
  final TtsConfigService _configService;

  bool _ready = false;
  bool _speaking = false;
  TtsVoicePreference _preference = TtsVoicePreference.malePastoral;
  TtsVoiceConfig _config = TtsVoiceConfig.defaults;

  bool get isReady => _ready;
  bool get isSpeaking => _speaking;
  TtsVoicePreference get preference => _preference;

  void Function(bool speaking)? onSpeakingChanged;
  void Function(String message)? onError;

  Future<void> initialize() async {
    try {
      _preference = await _preferenceStore.load();
      _config = await _configService.loadConfig();
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setVolume(1.0);
      _tts.setCompletionHandler(() {
        _speaking = false;
        onSpeakingChanged?.call(false);
      });
      await _applyVoiceSettings();
      _ready = true;
    } catch (e) {
      debugPrint('TtsReadAloudService init error: $e');
      _ready = kIsWeb;
    }
  }

  Future<void> refreshConfig(TtsVoiceConfig config) async {
    _config = config;
    if (_ready) await _applyVoiceSettings();
  }

  Future<void> setPreference(TtsVoicePreference preference) async {
    _preference = preference;
    await _preferenceStore.save(preference);
    // Voice is applied on the next speak() so TTS reconfiguration cannot
    // interfere with an active dictation (speech-to-text) session.
  }

  /// Applies the stored preference to the TTS engine (read-aloud only).
  Future<void> applyPreferenceFromStore() async {
    _preference = await _preferenceStore.load();
    if (_ready) await _applyVoiceSettings();
  }

  Future<void> _applyVoiceSettings() async {
    try {
      await _tts.setSpeechRate(_config.speechRate);
      final pitch = _preference == TtsVoicePreference.female
          ? _config.pitchFemale
          : _config.pitchMale;
      await _tts.setPitch(pitch);

      final rawVoices = await _tts.getVoices;
      final voices = TtsVoiceSelector.parseVoices(rawVoices);
      final selected = TtsVoiceSelector.selectVoice(
        voices: voices,
        preference: _preference,
        config: _config,
      );
      if (selected != null) {
        await _tts.setVoice(selected);
      }
    } catch (e) {
      debugPrint('TtsReadAloudService voice selection skipped: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_ready) {
      await initialize();
    }
    if (!_ready) {
      onError?.call('Read-aloud is not available on this device.');
      return;
    }

    final clean = _cleanForTts(text);
    if (clean.isEmpty) return;

    try {
      await applyPreferenceFromStore();
      _config = _configService.cached;
      await _applyVoiceSettings();
      await _tts.stop();
      _speaking = true;
      onSpeakingChanged?.call(true);
      await _tts.speak(clean);
    } catch (e) {
      _speaking = false;
      onSpeakingChanged?.call(false);
      onError?.call('Unable to read aloud.');
      debugPrint('TtsReadAloudService speak error: $e');
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _speaking = false;
    onSpeakingChanged?.call(false);
  }

  String _cleanForTts(String text) {
    return text
        .replaceAll(RegExp(r'http[s]?://[^\s]+'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'[#*_`>]'), '')
        .replaceAll(RegExp(r'\bV\.\s*'), '')
        .replaceAll(RegExp(r'\bR\.\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}

/// @deprecated Use [TtsReadAloudService] via [ttsReadAloudProvider].
typedef ReadAloudService = TtsReadAloudService;
