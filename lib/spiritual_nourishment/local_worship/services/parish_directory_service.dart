import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../../core/config.dart';
import '../models/parish.dart';
import 'mass_times_links.dart';

class ParishDirectoryException implements Exception {
  ParishDirectoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Nearby parish lookup via the official MassTimes Trust API (not HTML scraping).
///
/// Production web uses the `/api/nearby-parishes` Cloud Function to avoid
/// browser CORS. Native and local web call the documented API directly, then
/// fall back to the function URL.
class ParishDirectoryService {
  ParishDirectoryService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const _directApi =
      'https://apiv4.updateparishdata.org/Churchs/';
  static const _nominatimSearch =
      'https://nominatim.openstreetmap.org/search';
  static const _userAgent =
      'WWJD-DI/1.0 (https://wwjd-di-e36ce.web.app; local worship times)';

  final http.Client _http;

  Future<NearbySearchResult> search({
    String? address,
    double? latitude,
    double? longitude,
    int page = 1,
  }) async {
    final trimmed = address?.trim() ?? '';
    if ((latitude == null || longitude == null) && trimmed.isEmpty) {
      throw ParishDirectoryException(
        'Enter a street address or use the current location.',
      );
    }

    final errors = <String>[];
    final attempts = _searchOrder();
    for (final attempt in attempts) {
      try {
        return await attempt(
          address: trimmed,
          latitude: latitude,
          longitude: longitude,
          page: page,
        );
      } catch (error) {
        errors.add(error.toString());
      }
    }

    throw ParishDirectoryException(
      'Nearby parish data could not be loaded in the app. '
      'Use ${MassTimesLinks.homeUrl} to find times, then return to choose My Parish.\n'
      '${errors.isNotEmpty ? errors.last : ''}',
    );
  }

  List<Future<NearbySearchResult> Function({
    required String address,
    double? latitude,
    double? longitude,
    required int page,
  })> _searchOrder() {
    if (kIsWeb && !AppConfig.useClientSideXaiKey) {
      return [_searchViaProxy, _searchDirect];
    }
    return [_searchDirect, _searchViaProxy];
  }

  Future<NearbySearchResult> _searchViaProxy({
    required String address,
    double? latitude,
    double? longitude,
    required int page,
  }) async {
    final response = await _http
        .post(
          Uri.parse(AppConfig.nearbyParishesApiUrl),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            if (address.isNotEmpty) 'address': address,
            if (latitude != null) 'lat': latitude,
            if (longitude != null) 'lng': longitude,
            'page': page,
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 404) {
      throw ParishDirectoryException(
        'That address could not be found. Check the street, city, and ZIP.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ParishDirectoryException(
        'Parish lookup is temporarily unavailable (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw ParishDirectoryException('Parish lookup returned an unexpected response.');
    }
    return _resultFromPayload(Map<String, dynamic>.from(decoded));
  }

  Future<NearbySearchResult> _searchDirect({
    required String address,
    double? latitude,
    double? longitude,
    required int page,
  }) async {
    var lat = latitude;
    var lng = longitude;
    var label = address;

    if (lat == null || lng == null) {
      final origin = await _geocodeNominatim(address);
      lat = origin.latitude;
      lng = origin.longitude;
      label = origin.label.isNotEmpty ? origin.label : address;
    }

    final uri = Uri.parse(_directApi).replace(
      queryParameters: {
        'lat': lat.toString(),
        'long': lng.toString(),
        'pg': '$page',
      },
    );
    final response = await _http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      },
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ParishDirectoryException(
        'MassTimes parish data is temporarily unavailable (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw ParishDirectoryException('MassTimes parish data returned an unexpected response.');
    }

    return NearbySearchResult(
      origin: GeoOrigin(latitude: lat, longitude: lng, label: label),
      parishes: _parishesFromList(decoded),
    );
  }

  Future<GeoOrigin> _geocodeNominatim(String address) async {
    final uri = Uri.parse(_nominatimSearch).replace(
      queryParameters: {
        'q': address,
        'format': 'json',
        'limit': '1',
        'addressdetails': '0',
      },
    );
    final response = await _http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ParishDirectoryException('The address could not be located.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
      throw ParishDirectoryException(
        'That address could not be found. Check the street, city, and ZIP.',
      );
    }
    final first = Map<String, dynamic>.from(decoded.first as Map);
    final lat = double.tryParse(first['lat']?.toString() ?? '');
    final lon = double.tryParse(first['lon']?.toString() ?? '');
    if (lat == null || lon == null) {
      throw ParishDirectoryException('That address could not be found.');
    }
    return GeoOrigin(
      latitude: lat,
      longitude: lon,
      label: first['display_name']?.toString() ?? address,
    );
  }

  NearbySearchResult _resultFromPayload(Map<String, dynamic> payload) {
    final originRaw = payload['origin'];
    if (originRaw is! Map) {
      throw ParishDirectoryException('Parish lookup returned an unexpected response.');
    }
    final origin = GeoOrigin.fromMap(Map<String, dynamic>.from(originRaw));
    final churches = payload['churches'] ?? payload['parishes'];
    return NearbySearchResult(
      origin: origin,
      parishes: _parishesFromList(churches),
    );
  }

  List<Parish> _parishesFromList(dynamic raw) {
    if (raw is! List) return const [];
    final parishes = <Parish>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final parish = Parish.fromMassTimesApi(Map<String, dynamic>.from(item));
      if (parish.name.trim().isEmpty) continue;
      parishes.add(parish);
    }
    parishes.sort((a, b) {
      final da = a.distanceMiles ?? double.infinity;
      final db = b.distanceMiles ?? double.infinity;
      return da.compareTo(db);
    });
    return parishes;
  }
}
