import 'dart:typed_data';

/// Non-web platforms do not use the HTML file picker.
Future<({Uint8List bytes, String name})?> pickImageViaFileInput() async {
  return null;
}
