export 'device_location.dart';
export 'device_location_stub.dart'
    if (dart.library.html) 'device_location_web.dart'
    if (dart.library.io) 'device_location_io.dart';
