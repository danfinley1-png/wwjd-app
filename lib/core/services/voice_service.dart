import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text (dictation) for Seeking God's Wisdom — independent of read-aloud TTS.
class VoiceService {
  VoiceService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  bool _speechReady = false;

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
    await _ensureSpeechReady();
  }

  /// Re-initializes dictation if the engine was reset (e.g. after TTS reconfiguration).
  Future<void> _ensureSpeechReady() async {
    if (_speechReady) return;

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
  }

  Future<void> toggleListening() async {
    await _ensureSpeechReady();

    if (!_speechReady) {
      _onError?.call(
        'Speech recognition is not available. Check microphone permissions.',
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
      _speechReady = false;
      _onError?.call('Could not start listening: $e');
    }
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
  }
}
