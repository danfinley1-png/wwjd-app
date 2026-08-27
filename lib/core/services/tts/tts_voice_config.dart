/// Remote/local configuration for read-aloud voice selection.
class TtsVoiceConfig {
  const TtsVoiceConfig({
    required this.speechRate,
    required this.pitchMale,
    required this.pitchFemale,
    required this.maleVoiceHints,
    required this.femaleVoiceHints,
    this.maleVoiceNames = const [],
    this.femaleVoiceNames = const [],
    this.qualityHints = const ['premium', 'enhanced', 'natural', 'neural'],
  });

  final double speechRate;
  final double pitchMale;
  final double pitchFemale;
  final List<String> maleVoiceHints;
  final List<String> femaleVoiceHints;
  final List<String> maleVoiceNames;
  final List<String> femaleVoiceNames;
  final List<String> qualityHints;

  /// Built-in defaults — used when Firestore config is missing or unreachable.
  static const TtsVoiceConfig defaults = TtsVoiceConfig(
    speechRate: 0.85,
    pitchMale: 0.95,
    pitchFemale: 1.05,
    maleVoiceHints: [
      'daniel',
      'david',
      'james',
      'aaron',
      'guy',
      'ryan',
      'microsoft david',
      'google uk english male',
      'male',
    ],
    femaleVoiceHints: [
      'samantha',
      'zira',
      'karen',
      'victoria',
      'susan',
      'aria',
      'jenny',
      'microsoft zira',
      'google us english',
      'female',
    ],
    maleVoiceNames: [],
    femaleVoiceNames: [],
    qualityHints: ['premium', 'enhanced', 'natural', 'neural', 'wavenet'],
  );

  factory TtsVoiceConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return defaults;
    return TtsVoiceConfig(
      speechRate: _readDouble(map['speechRate'], defaults.speechRate),
      pitchMale: _readDouble(map['pitchMale'], defaults.pitchMale),
      pitchFemale: _readDouble(map['pitchFemale'], defaults.pitchFemale),
      maleVoiceHints:
          _readStringList(map['maleVoiceHints'], defaults.maleVoiceHints),
      femaleVoiceHints:
          _readStringList(map['femaleVoiceHints'], defaults.femaleVoiceHints),
      maleVoiceNames:
          _readStringList(map['maleVoiceNames'], defaults.maleVoiceNames),
      femaleVoiceNames:
          _readStringList(map['femaleVoiceNames'], defaults.femaleVoiceNames),
      qualityHints:
          _readStringList(map['qualityHints'], defaults.qualityHints),
    );
  }

  static double _readDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _readStringList(dynamic value, List<String> fallback) {
    if (value is! List || value.isEmpty) return fallback;
    return value.map((e) => e.toString().trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
  }
}
