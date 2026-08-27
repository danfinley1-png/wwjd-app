import 'parish_schedule.dart';

/// A Catholic church/parish shown on Local Worship Times cards.
class Parish {
  const Parish({
    required this.name,
    required this.address,
    this.id,
    this.latitude,
    this.longitude,
    this.distanceMiles,
    this.website,
    this.phone,
    this.schedule = const ParishSchedule(),
    this.isMyParish = false,
    this.isPerpetualAdorationChapel = false,
  });

  final String? id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? distanceMiles;
  final String? website;
  final String? phone;
  final ParishSchedule schedule;
  final bool isMyParish;
  final bool isPerpetualAdorationChapel;

  Parish copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? distanceMiles,
    String? website,
    String? phone,
    ParishSchedule? schedule,
    bool? isMyParish,
    bool? isPerpetualAdorationChapel,
  }) {
    return Parish(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      website: website ?? this.website,
      phone: phone ?? this.phone,
      schedule: schedule ?? this.schedule,
      isMyParish: isMyParish ?? this.isMyParish,
      isPerpetualAdorationChapel:
          isPerpetualAdorationChapel ?? this.isPerpetualAdorationChapel,
    );
  }

  String get distanceLabel {
    final miles = distanceMiles;
    if (miles == null) return '';
    if (miles < 0.1) return 'Less than 0.1 mi';
    if (miles < 10) return '${miles.toStringAsFixed(1)} mi';
    return '${miles.round()} mi';
  }

  bool get hasWebsite => website != null && website!.trim().isNotEmpty;
  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;

  /// Stable key for saving schedule edits for this parish.
  String get preferenceKey {
    final storedId = id?.trim();
    if (storedId != null && storedId.isNotEmpty) return 'id:$storedId';
    return 'name:${name.trim().toLowerCase()}|${address.trim().toLowerCase()}';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null && id!.isNotEmpty) 'id': id,
      'name': name,
      'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (distanceMiles != null) 'distanceMiles': distanceMiles,
      if (website != null) 'website': website,
      if (phone != null) 'phone': phone,
      'schedule': schedule.toMap(),
    };
  }

  factory Parish.fromMap(Map<String, dynamic> map) {
    final scheduleRaw = map['schedule'];
    return Parish(
      id: map['id']?.toString(),
      name: map['name']?.toString().trim() ?? '',
      address: map['address']?.toString().trim() ?? '',
      latitude: _asDouble(map['latitude']),
      longitude: _asDouble(map['longitude']),
      distanceMiles: _asDouble(map['distanceMiles'] ?? map['distance']),
      website: map['website']?.toString(),
      phone: map['phone']?.toString(),
      schedule: scheduleRaw is Map
          ? ParishSchedule.fromMap(Map<String, dynamic>.from(scheduleRaw))
          : const ParishSchedule(),
    );
  }

  /// Parses a MassTimes Trust API church object (not HTML).
  factory Parish.fromMassTimesApi(Map<String, dynamic> map) {
    final schedule = ParishSchedule.fromWorshipTimes(
      map['church_worship_times'] as Iterable<dynamic>?,
    );
    return Parish(
      id: map['id']?.toString(),
      name: (map['name'] ?? '').toString().trim(),
      address: formatAddress(map),
      latitude: _asDouble(map['latitude']),
      longitude: _asDouble(map['longitude']),
      distanceMiles: _asDouble(map['distance']),
      website: _normalizeWebsite(map['url']?.toString()),
      phone: _normalizePhone(map['phone_number']?.toString()),
      schedule: schedule,
      isPerpetualAdorationChapel: schedule.offersPerpetualAdoration,
    );
  }

  static String formatAddress(Map<String, dynamic> map) {
    final parts = <String>[
      map['church_address_street_address']?.toString().trim() ?? '',
      map['church_address_city_name']?.toString().trim() ?? '',
      map['church_address_providence_name']?.toString().trim() ?? '',
      map['church_address_postal_code']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();
    return parts.join(', ');
  }

  static String? _normalizeWebsite(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return 'https://$value';
  }

  static String? _normalizePhone(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }
}

class GeoOrigin {
  const GeoOrigin({
    required this.latitude,
    required this.longitude,
    this.label = '',
  });

  final double latitude;
  final double longitude;
  final String label;

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
      };

  factory GeoOrigin.fromMap(Map<String, dynamic> map) {
    return GeoOrigin(
      latitude: Parish._asDouble(map['latitude']) ?? 0,
      longitude: Parish._asDouble(map['longitude']) ?? 0,
      label: map['label']?.toString() ?? '',
    );
  }
}

class NearbySearchResult {
  const NearbySearchResult({
    required this.origin,
    required this.parishes,
  });

  final GeoOrigin origin;
  final List<Parish> parishes;
}
