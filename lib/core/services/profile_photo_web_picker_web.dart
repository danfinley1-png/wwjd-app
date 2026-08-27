import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Opens a native file chooser and reads the image with FileReader (no blob fetch).
///
/// Must be invoked synchronously from a user tap/click — do not `await` before calling.
Future<({Uint8List bytes, String name})?> pickImageViaFileInput() {
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png,image/webp,image/gif,.jpg,.jpeg,.png,.webp,.gif'
    ..multiple = false;

  // Edge/Chrome may ignore selections on `display:none` inputs — keep it invisible but present.
  input.style
    ..position = 'fixed'
    ..top = '0'
    ..left = '0'
    ..width = '1px'
    ..height = '1px'
    ..opacity = '0'
    ..pointerEvents = 'none';

  html.document.body?.append(input);

  final completer = Completer<({Uint8List bytes, String name})?>();

  void finish(({Uint8List bytes, String name})? value) {
    if (completer.isCompleted) return;
    input.remove();
    completer.complete(value);
  }

  input.onChange.listen((_) async {
    try {
      final files = input.files;
      if (files == null || files.isEmpty) {
        finish(null);
        return;
      }
      final file = files.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final result = reader.result;
      if (result is! ByteBuffer) {
        finish(null);
        return;
      }
      finish((
        bytes: result.asUint8List(),
        name: file.name,
      ));
    } catch (e) {
      if (!completer.isCompleted) {
        input.remove();
        completer.completeError(e);
      }
    }
  });

  input.click();

  // If the user closes the dialog without choosing, complete after a short wait.
  Timer(const Duration(seconds: 90), () {
    if (!completer.isCompleted) {
      finish(null);
    }
  });

  return completer.future;
}
