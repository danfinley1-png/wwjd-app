import '../models/parish.dart';

/// Selects My Parish first, then the next-closest churches from a nearby search.
class ParishRanking {
  ParishRanking._();

  static const int nearbyParishCount = 3;

  static List<Parish> featuredParishes({
    required List<Parish> nearby,
    Parish? myParish,
    int nearbyCount = nearbyParishCount,
  }) {
    final result = <Parish>[];
    if (myParish != null && myParish.name.trim().isNotEmpty) {
      final live = findMatchingParish(nearby, myParish) ?? myParish;
      result.add(live.copyWith(isMyParish: true));
    }

    final seen = <String>{
      for (final parish in result) parish.preferenceKey,
    };

    final others = [...nearby]..sort(_byDistance);
    var addedNearby = 0;
    for (final parish in others) {
      if (addedNearby >= nearbyCount) break;
      final key = parish.preferenceKey;
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(parish.copyWith(isMyParish: false));
      addedNearby++;
    }
    return result;
  }

  static Parish? closestPerpetualAdoration(List<Parish> nearby) {
    final chapels = nearby
        .where((parish) => parish.schedule.offersPerpetualAdoration)
        .toList()
      ..sort(_byDistance);
    if (chapels.isEmpty) return null;
    return chapels.first.copyWith(isPerpetualAdorationChapel: true);
  }

  static Parish? findMatchingParish(List<Parish> nearby, Parish saved) {
    final savedId = saved.id?.trim();
    if (savedId != null && savedId.isNotEmpty) {
      for (final parish in nearby) {
        if (parish.id == savedId) return parish;
      }
    }

    final savedName = saved.name.trim().toLowerCase();
    if (savedName.isEmpty) return null;
    Parish? nameMatch;
    for (final parish in nearby) {
      if (parish.name.trim().toLowerCase() != savedName) continue;
      nameMatch = parish;
      if (saved.latitude != null &&
          saved.longitude != null &&
          parish.latitude != null &&
          parish.longitude != null) {
        final dLat = (parish.latitude! - saved.latitude!).abs();
        final dLng = (parish.longitude! - saved.longitude!).abs();
        if (dLat < 0.02 && dLng < 0.02) return parish;
      }
    }
    return nameMatch;
  }

  static int _byDistance(Parish a, Parish b) {
    final da = a.distanceMiles ?? double.infinity;
    final db = b.distanceMiles ?? double.infinity;
    return da.compareTo(db);
  }
}
