import 'device_location.dart';

/// Native/desktop fallback when the geolocation plugin is not wired up.
/// Address entry still works; GPS is offered on web (and later on mobile).
class PlatformDeviceLocationService extends DeviceLocationService {
  const PlatformDeviceLocationService();

  @override
  bool get isSupported => false;

  @override
  Future<DeviceCoordinates> currentPosition() async {
    throw DeviceLocationException(
      'Current location is not available on this device. Enter a street address instead.',
    );
  }
}
