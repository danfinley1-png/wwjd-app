class DeviceCoordinates {
  const DeviceCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class DeviceLocationException implements Exception {
  DeviceLocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Platform geolocation. Hidden in the UI when [isSupported] is false.
abstract class DeviceLocationService {
  const DeviceLocationService();

  bool get isSupported;

  Future<DeviceCoordinates> currentPosition();
}
