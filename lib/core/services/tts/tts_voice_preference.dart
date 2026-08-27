/// User-selected read-aloud voice (TTS only — unrelated to AI responses).
enum TtsVoicePreference {
  malePastoral,
  female,
}

extension TtsVoicePreferenceStorage on TtsVoicePreference {
  String get storageKey => name;

  static TtsVoicePreference fromStorage(String? value) {
    switch (value) {
      case 'female':
        return TtsVoicePreference.female;
      case 'malePastoral':
      default:
        return TtsVoicePreference.malePastoral;
    }
  }

  String get label {
    switch (this) {
      case TtsVoicePreference.malePastoral:
        return 'Male (Pastoral)';
      case TtsVoicePreference.female:
        return 'Female';
    }
  }

  String get description {
    switch (this) {
      case TtsVoicePreference.malePastoral:
        return 'Warm, natural male voice for prayers and read-aloud.';
      case TtsVoicePreference.female:
        return 'Clear, natural female voice for prayers and read-aloud.';
    }
  }
}
