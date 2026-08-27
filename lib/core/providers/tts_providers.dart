import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tts/tts_config_service.dart';
import '../services/tts/tts_preference_store.dart';
import '../services/tts/tts_read_aloud_service.dart';
import '../services/tts/tts_voice_config.dart';
import '../services/tts/tts_voice_preference.dart';

final ttsPreferenceStoreProvider = Provider<TtsPreferenceStore>((ref) {
  return TtsPreferenceStore();
});

final ttsConfigServiceProvider = Provider<TtsConfigService>((ref) {
  return TtsConfigService();
});

final ttsVoiceConfigProvider = StreamProvider<TtsVoiceConfig>((ref) {
  return ref.watch(ttsConfigServiceProvider).watchConfig();
});

class TtsPreferenceNotifier extends StateNotifier<AsyncValue<TtsVoicePreference>> {
  TtsPreferenceNotifier(this._store) : super(const AsyncValue.loading()) {
    _load();
  }

  final TtsPreferenceStore _store;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final value = await _store.load();
      state = AsyncValue.data(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setPreference(TtsVoicePreference preference) async {
    state = AsyncValue.data(preference);
    await _store.save(preference);
  }
}

final ttsPreferenceProvider =
    StateNotifierProvider<TtsPreferenceNotifier, AsyncValue<TtsVoicePreference>>(
  (ref) => TtsPreferenceNotifier(ref.watch(ttsPreferenceStoreProvider)),
);

final ttsReadAloudProvider = Provider<TtsReadAloudService>((ref) {
  ref.keepAlive();
  final service = TtsReadAloudService(
    preferenceStore: ref.watch(ttsPreferenceStoreProvider),
    configService: ref.watch(ttsConfigServiceProvider),
  );

  ref.listen<AsyncValue<TtsVoiceConfig>>(ttsVoiceConfigProvider, (_, next) {
    next.whenData(service.refreshConfig);
  });

  ref.onDispose(service.dispose);
  return service;
});
