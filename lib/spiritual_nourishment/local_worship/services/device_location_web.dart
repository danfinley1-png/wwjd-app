import 'dart:html' as html;

import 'device_location.dart';

class PlatformDeviceLocationService extends DeviceLocationService {
  const PlatformDeviceLocationService();

  @override
  bool get isSupported => true;

  @override
  Future<DeviceCoordinates> currentPosition() async {
    final geo = html.window.navigator.geolocation;

    try {
      final position = await geo.getCurrentPosition(
        enableHighAccuracy: true,
        timeout: const Duration(seconds: 20),
      );
      final coords = position.coords;
      final lat = coords?.latitude;
      final lng = coords?.longitude;
      if (lat == null || lng == null) {
        throw DeviceLocationException('Current location could not be read.');
      }
      return DeviceCoordinates(
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
      );
    } catch (error) {
      if (error is DeviceLocationException) rethrow;
      throw DeviceLocationException(
        'Current location could not be used. Enter a street address instead.',
      );
    }
  }
}
