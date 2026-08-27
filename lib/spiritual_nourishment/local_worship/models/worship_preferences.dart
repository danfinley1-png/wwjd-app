import 'location_profile_kind.dart';
import 'parish.dart';
import 'parish_schedule.dart';

/// Saved address + My Parish for one location profile (neighborhood, school, …).
class LocationProfileState {
  const LocationProfileState({
    this.addressText = '',
    this.latitude,
    this.longitude,
    this.myParish,
    this.scheduleOverrides = const {},
  });

  final String addressText;
  final double? latitude;
  final double? longitude;
  final Parish? myParish;

  /// User-edited schedules, keyed by [Parish.preferenceKey].
  final Map<String, ParishSchedule> scheduleOverrides;

  bool get hasAddress => addressText.trim().isNotEmpty;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasMyParish => myParish != null && myParish!.name.trim().isNotEmpty;
  bool get isEmpty =>
      !hasAddress &&
      !hasCoordinates &&
      !hasMyParish &&
      scheduleOverrides.isEmpty;

  Parish displayParish(Parish parish) {
    final override = scheduleOverrides[parish.preferenceKey];
    if (override == null) return parish;
    return parish.copyWith(schedule: override);
  }

  LocationProfileState copyWith({
    String? addressText,
    double? latitude,
    double? longitude,
    Parish? myParish,
    Map<String, ParishSchedule>? scheduleOverrides,
    bool clearCoordinates = false,
    bool clearMyParish = false,
  }) {
    return LocationProfileState(
      addressText: addressText ?? this.addressText,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      myParish: clearMyParish ? null : (myParish ?? this.myParish),
      scheduleOverrides: scheduleOverrides ?? this.scheduleOverrides,
    );
  }

  LocationProfileState withScheduleOverride(Parish parish, ParishSchedule schedule) {
    return copyWith(
      scheduleOverrides: {
        ...scheduleOverrides,
        parish.preferenceKey: schedule,
      },
      myParish: hasMyParish && myParish!.preferenceKey == parish.preferenceKey
          ? myParish!.copyWith(schedule: schedule)
          : myParish,
    );
  }

  LocationProfileState withoutScheduleOverride(Parish parish) {
    final next = Map<String, ParishSchedule>.from(scheduleOverrides)
      ..remove(parish.preferenceKey);
    final sameParish = myParish != null &&
        myParish!.preferenceKey == parish.preferenceKey;
    return copyWith(
      scheduleOverrides: next,
      myParish: sameParish
          ? myParish!.copyWith(schedule: const ParishSchedule())
          : myParish,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'addressText': addressText,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (myParish != null) 'myParish': myParish!.toMap(),
      if (scheduleOverrides.isNotEmpty)
        'scheduleOverrides': {
          for (final entry in scheduleOverrides.entries)
            entry.key: entry.value.toMap(),
        },
    };
  }

  factory LocationProfileState.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const LocationProfileState();
    final parishRaw = map['myParish'];
    final overridesRaw = map['scheduleOverrides'];
    return LocationProfileState(
      addressText: map['addressText']?.toString() ?? '',
      latitude: _asDouble(map['latitude']),
      longitude: _asDouble(map['longitude']),
      myParish: parishRaw is Map
          ? Parish.fromMap(Map<String, dynamic>.from(parishRaw))
          : null,
      scheduleOverrides: _overridesFrom(overridesRaw),
    );
  }

  static Map<String, ParishSchedule> _overridesFrom(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key.toString(): ParishSchedule.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          ),
    };
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

/// Per-user Local Worship Times preferences (all location profiles).
class WorshipPreferences {
  const WorshipPreferences({this.profiles = const {}});

  final Map<String, LocationProfileState> profiles;

  bool get isEmpty => profiles.values.every((profile) => profile.isEmpty);

  LocationProfileState forKind(LocationProfileKind kind) =>
      profiles[kind.id] ?? const LocationProfileState();

  WorshipPreferences withProfile(
    LocationProfileKind kind,
    LocationProfileState state,
  ) {
    return WorshipPreferences(
      profiles: {
        ...profiles,
        kind.id: state,
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profiles': {
        for (final entry in profiles.entries)
          if (!entry.value.isEmpty) entry.key: entry.value.toMap(),
      },
    };
  }

  factory WorshipPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const WorshipPreferences();
    final raw = map['profiles'];
    if (raw is! Map) return const WorshipPreferences();
    return WorshipPreferences(
      profiles: {
        for (final entry in raw.entries)
          if (entry.value is Map)
            entry.key.toString(): LocationProfileState.fromMap(
              Map<String, dynamic>.from(entry.value as Map),
            ),
      },
    );
  }

  /// Keep account values when present; fill gaps from guest/local data.
  static WorshipPreferences mergePreferringExisting(
    WorshipPreferences? existing,
    WorshipPreferences incoming,
  ) {
    if (existing == null || existing.isEmpty) return incoming;
    final merged = Map<String, LocationProfileState>.from(existing.profiles);
    for (final entry in incoming.profiles.entries) {
      final current = merged[entry.key];
      if (current == null || current.isEmpty) {
        merged[entry.key] = entry.value;
        continue;
      }
      merged[entry.key] = LocationProfileState(
        addressText: current.hasAddress ? current.addressText : entry.value.addressText,
        latitude: current.latitude ?? entry.value.latitude,
        longitude: current.longitude ?? entry.value.longitude,
        myParish: current.hasMyParish ? current.myParish : entry.value.myParish,
        scheduleOverrides: {
          ...entry.value.scheduleOverrides,
          ...current.scheduleOverrides,
        },
      );
    }
    return WorshipPreferences(profiles: merged);
  }
}
