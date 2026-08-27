import 'package:shared_preferences/shared_preferences.dart';

import 'tts_voice_preference.dart';

/// Persists the user's read-aloud voice choice locally.
class TtsPreferenceStore {
  TtsPreferenceStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _key = 'tts_voice_preference';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<TtsVoicePreference> load() async {
    final prefs = await _ensurePrefs();
    return TtsVoicePreferenceStorage.fromStorage(prefs.getString(_key));
  }

  Future<void> save(TtsVoicePreference preference) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_key, preference.storageKey);
  }
}
