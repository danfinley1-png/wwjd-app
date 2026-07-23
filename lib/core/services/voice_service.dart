import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text and text-to-speech for Seeking God's Wisdom.
class VoiceService {
  VoiceService({
    SpeechToText? speech,
    FlutterTts? tts,
  })  : _speech = speech ?? SpeechToText(),
        _tts = tts ?? FlutterTts();

  final SpeechToText _speech;
  final FlutterTts _tts;

  bool _speechReady = false;
  bool _ttsReady = false;

  void Function(String text)? _onPartialText;
  void Function(bool listening)? _onListeningChanged;
  void Function(String message)? _onError;

  bool get isListening => _speech.isListening;
  bool get speechAvailable => _speechReady;

  Future<void> initialize({
    required void Function(String text) onPartialText,
    required void Function(bool listening) onListeningChanged,
    required void Function(String message) onError,
  }) async {
    _onPartialText = onPartialText;
    _onListeningChanged = onListeningChanged;
    _onError = onError;

    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          _onListeningChanged?.call(false);
        }
      },
      onError: (error) {
        _onListeningChanged?.call(false);
        _onError?.call(_friendlySpeechError(error.errorMsg));
      },
    );

    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.85);
      await _tts.setPitch(0.9);
      await _tts.setVolume(1.0);
      await _pickBestVoice();
      _ttsReady = true;
    } catch (e) {
      debugPrint('VoiceService TTS init error: $e');
      _ttsReady = kIsWeb; // Web may still speak with defaults
    }
  }

  Future<void> _pickBestVoice() async {
    try {
      final dynamic rawVoices = await _tts.getVoices;
      if (rawVoices is! List || rawVoices.isEmpty) return;

      Map<String, String>? selected;
      for (final entry in rawVoices) {
        if (entry is! Map) continue;
        final name = entry['name']?.toString() ?? '';
        final locale = entry['locale']?.toString() ?? '';
        if (!locale.toLowerCase().startsWith('en')) continue;

        selected ??= {'name': name, 'locale': locale};

        final lower = name.toLowerCase();
        if (lower.contains('daniel') ||
            lower.contains('david') ||
            lower.contains('james') ||
            lower.contains('male')) {
          selected = {'name': name, 'locale': locale};
          break;
        }
      }

      if (selected != null) {
        await _tts.setVoice(selected);
      }
    } catch (e) {
      debugPrint('VoiceService voice selection skipped: $e');
    }
  }

  Future<void> toggleListening() async {
    if (!_speechReady) {
      _onError?.call(
        kIsWeb
            ? 'Voice input requires a browser that supports the Web Speech API (e.g. Chrome or Edge).'
            : 'Speech recognition is not available. Check microphone permissions.',
      );
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();
      _onListeningChanged?.call(false);
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          _onPartialText?.call(result.recognizedWords);
          if (result.finalResult) {
            _onListeningChanged?.call(false);
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: true,
          localeId: 'en_US',
        ),
      );
      _onListeningChanged?.call(true);
    } catch (e) {
      _onListeningChanged?.call(false);
      _onError?.call('Could not start listening: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_ttsReady) {
      _onError?.call('Read-aloud is not available on this device.');
      return;
    }

    final clean = _cleanForTts(text);
    if (clean.isEmpty) return;

    try {
      await _tts.stop();
      await _tts.speak(clean);
    } catch (e) {
      _onError?.call('Unable to read aloud.');
      debugPrint('VoiceService speak error: $e');
    }
  }

  String _cleanForTts(String text) {
    return text
        .replaceAll(RegExp(r'http[s]?://[^\s]+'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'[#*_`>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _friendlySpeechError(String message) {
    if (message.contains('error_permission')) {
      return 'Microphone permission is required for voice input.';
    }
    if (message.contains('error_no_match')) {
      return 'Did not catch that — please try again.';
    }
    return 'Speech recognition error: $message';
  }

  Future<void> dispose() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    await _tts.stop();
  }
}
