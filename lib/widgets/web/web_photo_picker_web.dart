import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/services/profile_photo_service.dart';

int _pickerId = 0;

/// Real HTML [label] + [input type=file] — the most reliable web/Edge file picker.
class WebNativePhotoPicker extends StatefulWidget {
  const WebNativePhotoPicker({
    super.key,
    required this.onPicked,
    this.onError,
    this.busy = false,
    this.label = 'Choose photo',
  });

  final void Function(ProfilePhotoPick pick) onPicked;
  final void Function(Object error)? onError;
  final bool busy;
  final String label;

  @override
  State<WebNativePhotoPicker> createState() => _WebNativePhotoPickerState();
}

class _WebNativePhotoPickerState extends State<WebNativePhotoPicker> {
  late final String _viewType = 'wwjd-photo-picker-${_pickerId++}';
  late final String _inputId = '$_viewType-input';
  html.LabelElement? _labelElement;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final container = html.DivElement();
      container.style
        ..display = 'flex'
        ..justifyContent = 'center'
        ..alignItems = 'center'
        ..width = '100%'
        ..height = '48px';

      final input = html.FileUploadInputElement()
        ..id = _inputId
        ..accept = 'image/jpeg,image/png,image/webp,image/gif,.jpg,.jpeg,.png'
        ..style.display = 'none';

      _labelElement = html.LabelElement()
        ..htmlFor = _inputId
        ..text = widget.label;
      _labelElement!.style
        ..display = 'inline-block'
        ..padding = '12px 20px'
        ..backgroundColor = '#8B1E1E'
        ..color = '#FFFFFF'
        ..borderRadius = '8px'
        ..cursor = 'pointer'
        ..fontFamily = 'Segoe UI, system-ui, sans-serif'
        ..fontSize = '15px'
        ..fontWeight = '600'
        ..userSelect = 'none';

      input.onChange.listen((_) => _readFile(input));

      container.children.addAll([_labelElement!, input]);
      return container;
    });
  }

  @override
  void didUpdateWidget(WebNativePhotoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      _labelElement?.text = widget.label;
    }
  }

  Future<void> _readFile(html.FileUploadInputElement input) async {
    try {
      final files = input.files;
      if (files == null || files.isEmpty) return;

      final file = files.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final result = reader.result;
      if (result is! ByteBuffer) return;

      final bytes = result.asUint8List();
      if (bytes.isEmpty) return;

      final name = file.name;
      widget.onPicked(
        ProfilePhotoPick(
          bytes: bytes,
          contentType: _contentTypeForName(name),
          name: name,
        ),
      );
    } catch (e) {
      widget.onError?.call(e);
    } finally {
      input.value = '';
    }
  }

  static String _contentTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: HtmlElementView(viewType: _viewType),
        ),
        const SizedBox(height: 6),
        Text(
          'JPG or PNG, under 5 MB',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.primaryMaroon.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
