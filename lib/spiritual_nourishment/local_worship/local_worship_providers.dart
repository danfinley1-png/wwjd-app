import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/location_profile_kind.dart';
import 'models/worship_preferences.dart';
import 'services/device_location_platform.dart';
import 'services/local_worship_preference_store.dart';
import 'services/parish_directory_service.dart';

final localWorshipPreferenceStoreProvider =
    Provider<LocalWorshipPreferenceStore>(
  (ref) => LocalWorshipPreferenceStore(),
);

final parishDirectoryServiceProvider = Provider<ParishDirectoryService>(
  (ref) => ParishDirectoryService(),
);

final deviceLocationServiceProvider = Provider<DeviceLocationService>(
  (ref) => const PlatformDeviceLocationService(),
);

final localWorshipPreferencesProvider =
    AsyncNotifierProvider<LocalWorshipPreferencesNotifier, WorshipPreferences>(
  LocalWorshipPreferencesNotifier.new,
);

class LocalWorshipPreferencesNotifier
    extends AsyncNotifier<WorshipPreferences> {
  LocalWorshipPreferenceStore get _store =>
      ref.read(localWorshipPreferenceStoreProvider);

  @override
  Future<WorshipPreferences> build() => _store.load();

  Future<void> updateProfile(
    LocationProfileKind kind,
    LocationProfileState Function(LocationProfileState current) transform,
  ) async {
    final current = state.valueOrNull ?? const WorshipPreferences();
    final next = current.withProfile(kind, transform(current.forKind(kind)));
    state = AsyncData(next);
    await _store.save(next);
  }

  Future<void> migrateAfterSignIn() async {
    final merged = await _store.migrateLocalToSignedInAccount();
    state = AsyncData(merged);
  }
}
