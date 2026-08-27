import 'package:flutter/material.dart';

/// Non-web: use regular Flutter image widgets.
Widget buildWebProfileImage({
  required String imageUrl,
  required double size,
}) {
  return SizedBox(width: size, height: size);
}
