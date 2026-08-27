import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

import 'device_location.dart';

class PlatformDeviceLocationService extends DeviceLocationService {
  const PlatformDeviceLocationService();

  @override
  bool get isSupported {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<DeviceCoordinates> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw DeviceLocationException(
        'Location services are turned off. Enter a street address instead.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw DeviceLocationException(
        'Location permission was not granted. Enter a street address instead.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return DeviceCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
