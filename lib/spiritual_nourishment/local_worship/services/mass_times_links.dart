/// Official MassTimes.org deep links (no HTML scraping).
class MassTimesLinks {
  MassTimesLinks._();

  static const String homeUrl = 'https://masstimes.org';
  static const String mapUrl = 'https://masstimes.org/map';

  static Uri home() => Uri.parse(homeUrl);

  /// Nearby map search. [lng] matches the MassTimes.org query parameter.
  static Uri nearbyMap({
    double? latitude,
    double? longitude,
    String? searchQuery,
  }) {
    return Uri.parse(mapUrl).replace(
      queryParameters: {
        if (latitude != null) 'lat': latitude.toStringAsFixed(5),
        if (longitude != null) 'lng': longitude.toStringAsFixed(5),
        if (searchQuery != null && searchQuery.trim().isNotEmpty)
          'SearchQueryTerm': searchQuery.trim(),
        'sortDistance': '',
      },
    );
  }

  static Uri parishOnMap(ParishLinkTarget parish) {
    final query = parish.name.trim().isNotEmpty ? parish.name.trim() : parish.address;
    return nearbyMap(
      latitude: parish.latitude,
      longitude: parish.longitude,
      searchQuery: query,
    );
  }

  static Uri adorationMap({
    double? latitude,
    double? longitude,
    String? searchQuery,
  }) {
    return nearbyMap(
      latitude: latitude,
      longitude: longitude,
      searchQuery: searchQuery,
    );
  }
}

class ParishLinkTarget {
  const ParishLinkTarget({
    required this.name,
    this.address = '',
    this.latitude,
    this.longitude,
  });

  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
}
