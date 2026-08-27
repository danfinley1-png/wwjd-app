import 'package:cloud_firestore/cloud_firestore.dart';

import 'tts_voice_config.dart';

/// Loads TTS voice hints from Firestore `config/tts` with local defaults.
class TtsConfigService {
  TtsConfigService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _docPath = 'config/tts';

  TtsVoiceConfig _cached = TtsVoiceConfig.defaults;

  TtsVoiceConfig get cached => _cached;

  Stream<TtsVoiceConfig> watchConfig() async* {
    yield _cached;
    try {
      await for (final snap in _firestore.doc(_docPath).snapshots()) {
        _cached = TtsVoiceConfig.fromMap(snap.data());
        yield _cached;
      }
    } catch (_) {
      yield _cached;
    }
  }

  Future<TtsVoiceConfig> loadConfig() async {
    try {
      final snap = await _firestore.doc(_docPath).get();
      _cached = TtsVoiceConfig.fromMap(snap.data());
    } catch (_) {
      _cached = TtsVoiceConfig.defaults;
    }
    return _cached;
  }
}
